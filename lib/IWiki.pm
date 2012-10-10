# vim: set ft=perl :

package IWiki;
use strict;
use warnings;
use utf8;

our $VERSION = '0.0.1';

use FindBin;
use Carp                  qw/croak carp/;
use Encode                qw/encode from_to/;
use Encode::Guess         qw/euc-jp shiftjis 7bit-jis/;
use File::stat            qw/stat/;
use File::Spec::Functions qw/catfile catdir canonpath/;
use File::Basename        qw/fileparse dirname/;
use File::Find            qw/find/;
use File::Path            qw/mkpath/;
use HTTP::Date            qw/str2time time2str/;
use DBI;
use XML::LibXSLT;
use IWiki::Util           qw/htmlout html_escape canonicalize_header/;
use IWiki::Page;


my $debug        = 0;
my $text_dir     = catfile($FindBin::Bin, 'text');
my $template_dir = catfile($FindBin::Bin, 'template');
my $cache_dir    = catfile($FindBin::Bin, 'cache');
my $use_cache    = 0;
my $db_filename  = 'cache.sqlite';
my @rules        = (
    {
        match_path_info => qr{(?:/.+\.html|/)\z},
        template => 'default.xsl',
    }
);
my @valid_extensions = qw/.html/;
my $default_extension = '.html';

my @envvars = qw/SERVER_ADDR SERVER_ADMIN SERVER_NAME SERVER_PORT
SERVER_PROTOCOL SERVER_SIGNATURE SERVER_SOFTWARE REMOTE_ADDR
REMOTE_PORT REQUEST_METHOD REQUEST_URI SCRIPT_FILENAME SCRIPT_NAME
PATH_INFO/;

# IWiki->new()
sub new {
    my $class = shift || croak "new(): no class name";
    my $self = bless {
        debug            => $debug,
        text_dir         => $text_dir,
        template_dir     => $template_dir,
        cache_dir        => $cache_dir,
        use_cache        => $use_cache,
        rules            => \@rules,
        xslt_params      => {},
        user_ns          => {},
        valid_extensions => \@valid_extensions,
        default_extension => $default_extension,
        @_ } => $class;

    $ENV{REQUEST_METHOD} = "GET" if not defined $ENV{REQUEST_METHOD};
    for my $env (@envvars) {
        $ENV{$env} = "" unless defined $ENV{$env};
        $self->{xslt_params}{$env} = $ENV{$env};
    }

    -d $self->{template_dir} and -r _
        or croak "start(): no such a directory or not readable: $self->{template_dir}";

    for my $rule (@{$self->{rules}}) {
        ref $rule eq "HASH"
            or croak "start(): each rule must be a HASH ref";
        defined $rule->{template}
            or  croak "start(): each rule must have 'template' keys"
    }

    if ($self->{use_cache}) {
        my $db_file = catfile($self->{cache_dir}, $db_filename);
        $self->{dbh} = DBI->connect("dbi:SQLite:dbname=$db_file",
            undef, undef, {
                RaiseError => 1,
                PrintError => 1,
                AutoCommit => 1,
            });

        my $count = $self->{dbh}->selectrow_array(qq{
SELECT count(*) FROM sqlite_master
  WHERE type='table' AND name='pagedata';
});

        if ($count == 0) {
            $self->{dbh}->do(qq{
CREATE TABLE pagedata (
  text_path,
  template_path,
  text_mtime,
  template_mtime,
  http_body,
  media_type,
  encoding,
  last_cached,
  PRIMARY KEY(text_path, template_path)
);
        });
        }

        #$self->purge_cache;
    }

    $self;
}

sub DESTORY {
    my $self = shift;
    defined $self->{dbh} and $self->{dbh}->disconnect;
}

# $self->start()
sub start {
    my $self = shift;

    if ($ENV{REQUEST_METHOD} =~ /\A(GET|HEAD|POST)\z/) {
        my $page     = IWiki::Page->new(
            text_dir          => $self->{text_dir},
            valid_extensions  => $self->{valid_extensions},
            default_extension => $self->{default_extension},
            user_ns           => $self->{user_ns},
            cache_dir         => $self->{cache_dir},
            use_cache         => $self->{use_cache},
        );
        if ($page->is_ok) {
            my $modified_since = defined $ENV{HTTP_IF_MODIFIED_SINCE} ?
            str2time($ENV{HTTP_IF_MODIFIED_SINCE}) : undef;
            my $template_rule = $self->_get_template_rule($page);
            if (defined $modified_since
                    and $page->mtime <= $modified_since
                    and not $template_rule->{ignore_last_modified}) {
                print $self->response('', 'Status' => '304 Not Modified');
            }
            else {
                my $pagedata = $self->_get_pagedata($page, $template_rule);
                if ($pagedata) {
                    my %headers = (
                        'Status' => '200 OK',
                        'Cache-Control' => 'private, max-age='.(60*60*24),
                        'Content-Type' => $pagedata->{media_type}
                        . ";charset=" . $pagedata->{encoding},
                    );
                    $headers{'Last-Modified'} = time2str($page->mtime)
                        unless $template_rule->{ignore_last_modified};
                    # $headers{'eTag'} = sprintf q{"%x-%x-%x"}, (stat($page->text_path))[1,7,9];
                    for my $key (grep {index($_, 'http_') == 0} keys %{$template_rule}) {
                        $headers{canonicalize_header(substr($key, 5))}
                        = $template_rule->{$key};
                    }
                    print $self->response(
                        $ENV{REQUEST_METHOD} eq "HEAD" ? "" : $pagedata->{http_body}
                        , %headers);
                }
                else {
                    print $self->error(404);
                }
            }
        }
        elsif ($page->is_forbidden) {
            print $self->error(403);
        }
        else {
            print $self->error(404);
        }
    }
    else {
        print $self->error(501);
    }
}

# $self->_get_pagedata_from_db($text_path, $template_path)
sub _get_pagedata_from_db {
    my $self = shift;
    croak "_get_pagedata_from_db(): cache is disabled"
        unless $self->{use_cache};
    my $pagedata;
    my $sth = $self->{dbh}->prepare(qq{
SELECT text_mtime,
       template_mtime,
       http_body,
       media_type,
       encoding,
       last_cached
FROM pagedata
WHERE text_path = ? AND template_path = ?;
        });
    $sth->execute($_[0], $_[1]);
    if (my @pd = $sth->fetchrow_array) {
        $pagedata = {
            text_mtime     => $pd[0],
            template_mtime => $pd[1],
            http_body      => $pd[2],
            media_type     => $pd[3],
            encoding       => $pd[4],
            last_cached    => $pd[5],
        };
    }
    $sth->finish;
    $pagedata;
}

# $self->_set_pagedata_into_db($pagedata, $text_path, $template_path)
sub _set_pagedata_into_db {
    my $self = shift;
    croak "_set_pagedata_into_db(): cache is disabled"
        unless $self->{use_cache};
    my ($pagedata, $text_path, $template_path) = @_;

    my $count = $self->{dbh}->selectrow_array(qq{
SELECT count(*)
FROM pagedata
WHERE text_path = ? AND template_path = ?;
}, undef, $text_path, $template_path);
    if ($count == 0) {
        my $sth = $self->{dbh}->prepare(qq{
INSERT INTO pagedata VALUES(
  ?, ?, ?, ?, ?, ?, ?, ?
);
        });
        $sth->execute(
                $text_path, $template_path,
                $pagedata->{text_mtime}, $pagedata->{template_mtime},
                $pagedata->{http_body}, $pagedata->{media_type},
                $pagedata->{encoding}, time
            );
        $sth->finish;
    }
    else {
        my $sth = $self->{dbh}->prepare(qq{
UPDATE pagedata
SET text_mtime = ?,
    template_mtime = ?,
    http_body = ?,
    media_type = ?,
    encoding = ?,
    last_cached = ?
WHERE text_path = ? AND template_path = ?;
        });
        $sth->execute(
            $pagedata->{text_mtime}, $pagedata->{template_mtime},
            $pagedata->{http_body}, $pagedata->{media_type},
            $pagedata->{encoding}, time,
            $text_path, $template_path
        );
        $sth->finish;
    }
}

# $self->_get_pagedata($page, [$template_rule])
sub _get_pagedata {
    my $self = shift;
    my $page = shift;
    my $template_rule = shift || $self->_get_template_rule($page);
    return undef unless defined $template_rule;

    my $template_path = $self->_get_template_path($template_rule);
    -f $template_path and -r _
        or croak "_get_pagedata(): no such a file or not readable: $template_path.";

    my $pagedata;
    my $template_stat = stat $template_path;
    my $save_cache = 0;

    if ($self->{use_cache}) {
        $pagedata = $self->_get_pagedata_from_db($page->text_path,
            $template_path);
        if ($pagedata) {
            if ($pagedata->{text_mtime} != $page->mtime
                  or $pagedata->{template_mtime} != $template_stat->mtime
                  or time - $pagedata->{last_cached} > ($template_rule->{expiry} || 60 * 60 * 24)) {
                $save_cache = 1;
                $pagedata = undef;
            }
        }
        else {
            $save_cache = 1;
        }
    }

    unless ($pagedata) {
        my $xslt = XML::LibXSLT->new;
        my $stylesheet = $xslt->parse_stylesheet_file($template_path);
        my $doc = $stylesheet->transform($page->to_xmldoc,
            XML::LibXSLT::xpath_to_string(
                path_info  => $page->path_info,
                dirname    => $page->dirname,
                basename   => $page->basename,
                extension  => $page->extension,
                text_path  => $page->text_path,
                mtime      => $page->mtime,
                media_type => $stylesheet->media_type,
                encoding   => $stylesheet->output_encoding,
                %{$self->{xslt_params}}));
        my $http_body = "";
        # the older version of XML::LibXSLT doesn't support 'output_as_bytes'
        if ($stylesheet->can('output_as_bytes')) {
            $http_body = $stylesheet->output_as_bytes($doc);
        }
        else {
            my $body = $stylesheet->output_string($doc);
            if (utf8::is_utf8 $body) {
                $body = encode($stylesheet->output_encoding, $body);
            }
            else {
                my $guessed = guess_encoding($body);
                if (ref $guessed) {
                    if (lc($guessed->mime_name) ne lc($stylesheet->output_encoding)) {
                        $body = from_to($body, $guessed, $stylesheet->output_encoding);
                    }
                }
                else {
                    croak "string returned by \$stylesheet->output_string is broken.";
                }
            }
            $http_body = $body;
        }
        $pagedata = {
            text_mtime     => $page->mtime,
            template_mtime => $template_stat->mtime,
            http_body      => $http_body,
            media_type     => $stylesheet->media_type,
            encoding       => $stylesheet->output_encoding,
        };

        if ($self->{use_cache} and $save_cache) {
            $self->_set_pagedata_into_db(
                $pagedata, $page->text_path, $template_path
            );
        }
    }
    return $pagedata;
}

# $self->_get_template_rule($page)
sub _get_template_rule {
    my $self = shift;
    my $page = shift;
    for my $rule (@{$self->{rules}}) {
        if (keys %{$rule} eq 1) { # only 'template' key
            return $rule;
        }
        else {
            my $ok = 1;
            while (my ($key, $value) = each %{$rule}) {
                if (index($key, 'env_') == 0 and defined $ENV{substr($key, 4)}) {
                    $ok = 0, last unless ($ENV{substr($key, 4)} =~ /$value/);
                }
                elsif (grep {$key eq 'match_'.$_}
                    qw/path_info dirname basename extension text_path/) {
                    my $_key = substr($key, 6);
                    $ok = 0, last unless ($page->$_key =~ /$value/);
                }
            }
            $ok and return $rule;
        }
    }
    return undef;
}

# $self->_get_template_path($rule)
sub _get_template_path {
    my $self = shift;
    my $rule = shift or return "";
    return catfile($self->{template_dir}, $rule->{template});
}

# $self->purge_cache()
sub purge_cache {
    my $self = shift;
    croak "purge_cache(): cache is disabled" unless $self->{use_cache};

    if ($self->{dbh}->selectrow_array(qq{
SELECT count(*) FROM sqlite_master
  WHERE type='table' AND name='pagedata';
}) == 1){
        my $sth = $self->{dbh}->prepare(qq{
SELECT text_path, template_path
FROM pagedata;
            });
        $sth->execute;
        while (my ($text_path, $template_path) = $sth->fetchrow_array) {
            if (not -f $text_path or not -f $template_path) {
                my $sth_delete = $self->{dbh}->prepare(qq{
DELETE FROM pagedata
WHERE text_path = ? AND template_path = ?;'
                    });
                $sth_delete->execute($text_path, $template_path);
                $sth_delete->finish;
            }
        }
        $sth->finish;
    }

    if ($self->{dbh}->selectrow_array(qq{
SELECT count(*) FROM sqlite_master
  WHERE type='table' AND name='pagexml';
}) == 1){
        my $sth = $self->{dbh}->prepare(qq{SELECT text_path FROM pagexml;});
        $sth->execute;
        while (my ($text_path) = $sth->fetchrow_array) {
            if (not -f $text_path) {
                my $sth_delete = $self->{dbh}->prepare(qq{
DELETE FROM pagexml WHERE text_path = ?;'
                    });
                $sth_delete->execute($text_path);
                $sth_delete->finish;
            }
        }
        $sth->finish;
    }
}

# $self->response($http_body, %headers)
# $http_body and %headers must be encoded.
sub response {
    my $self = shift;
    my $http_body = shift;
    croak "response(): hash conmposed of odd number of elements" if @_ % 2 == 1;

    my %headers = @_;
    %headers = map { canonicalize_header($_) => $headers{$_} } keys %headers;
    $headers{'Status'}        ||= '200 OK';
    $headers{'Content-Type'}  ||= 'text/html';
    my $http_header = join("\n", map { "$_: $headers{$_}" } keys %headers);
    return "$http_header\n\n$http_body";
}

# $self->error($status_code, $detail)
sub error {
    my $self = shift;
    my $status_code = shift;
    my $detail      = shift;
    my %headers     = ();

    my %status_phrases = (
        400 => 'Bad Request',
        401 => 'Unauthorized',
        402 => 'Payment Required',
        403 => 'Forbidden',
        404 => 'Not Found',
        405 => 'Method Not Allowed',
        406 => 'Not Acceptable',
        407 => 'Proxy Authentication Required',
        408 => 'Request Timeout',
        409 => 'Conflict',
        410 => 'Gone',
        411 => 'Length Required',
        412 => 'Precondition Failed',
        413 => 'Request Entity Too Large',
        414 => 'Request-URI Too Long',
        415 => 'Unsupported Media Type',
        416 => 'Requested Range Not Satisfiable',
        417 => 'Expectation Failed',
        422 => 'Unprocessable Entity',
        423 => 'Locked',
        424 => 'Failed Dependency',
        426 => 'Upgrade Required',
        500 => 'Internal Server Error',
        501 => 'Not Implemented',
        502 => 'Bad Gateway',
        503 => 'Service Unavailable',
        504 => 'Gateway Timeout',
        505 => 'HTTP Version Not Supported',
        506 => 'Variant Also Negotiates',
        508 => 'Loop Detected',
        510 => 'Not Extended',
    );

    unless (defined $status_phrases{$status_code}) {
        carp "error(): Status code '$status_code' is unknown.";
        return;
    }

    my %status_messages = ();
    $status_messages{400} = <<EOD;
Your browser (or proxy) sent a request that this server could not understand.
EOD
    $status_messages{401} = <<EOD;
This server could not verify that you are authorized to access the URL.
You either supplied the wrong credentials (e.g., bad password), or your
browser doesn't understand how to supply the credentials required.

In case you are allowed to request the document, please check your user-id
and password and try again.
EOD
    $status_messages{403} = <<EOD;
You don't have permission to access the requested object. It is either
read-protected or not readable by the server.
EOD
    $status_messages{404} = <<EOD;
The requested URL was not found on this server. If you entered the URL
manually please check your spelling and try again.
EOD
    $status_messages{405} = <<EOD;
The method is not allowed for the requested URL.
EOD
    $status_messages{406} = <<EOD;
An appropriate representation of the requested resource could not be
found on this server.
EOD
    $status_messages{408} = <<EOD;
The server closed the network connection because the browser
didn't finish the request within the specified time.
EOD
    $status_messages{410} = <<EOD;
The requested URL is no longer available on this server and there is no
forwarding address.
If you followed a link from a foreign page, please contact the
author of this page.
EOD
    $status_messages{411} = <<EOD;
A request with the method requires a valid Content-Length header.
EOD
    $status_messages{412} = <<EOD;
The precondition on the request for the URL failed positive evaluation.
EOD
    $status_messages{413} = <<EOD;
The method does not allow the data transmitted, or the data volume
exceeds the capacity limit.
EOD
    $status_messages{414} = <<EOD;
The length of the requested URL exceeds the capacity limit for
this server. The request cannot be processed.
EOD
    $status_messages{415} = <<EOD;
The server does not support the media type transmitted in the request.
EOD
    $status_messages{500} = <<EOD;
The server encountered an internal error and was unable to complete
your request. Either the server is overloaded or there was an error
in a CGI script.
EOD
    $status_messages{501} = <<EOD;
The server does not support the action requested by the browser.
EOD
    $status_messages{502} = <<EOD;
The proxy server received an invalid
response from an upstream server.
EOD
    $status_messages{503} = <<EOD;
The server is temporarily unable to service your
request due to maintenance downtime or capacity
problems. Please try again later.
EOD
    $status_messages{506} = <<EOD;
A variant for the requested entity
is itself a negotiable resource.
Access not possible.
EOD
    $headers{'Cache-Control'} = 'private';
    $headers{'Content-Type'}  = 'text/html;charset=UTF-8';
    $headers{'Status'}        = "$status_code $status_phrases{$status_code}";

    my $http_body = <<EOD;
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01//EN">
<meta http-equiv="Content-Type" content="$headers{'Content-Type'}">
<title>@{[html_escape $headers{'Status'}]}</title>
<h1>@{[html_escape $headers{'Status'}]}</h1>
EOD

    if (defined $status_messages{$status_code}) {
        $http_body .= "<p>@{[html_escape $status_messages{$status_code}]}</p>";
    }
    if (defined $ENV{SERVER_ADMIN}) {
        $http_body .= <<EOD;
<p>If you think this is a server error, please contact
the <a href="mailto:@{[html_escape $ENV{SERVER_ADMIN}]}">webmaster</a>.</p>
EOD
    }
    if (defined $ENV{SERVER_SIGNATURE}) {
        $http_body .= "<hr><div>$ENV{SERVER_SIGNATURE}</div>";
    }
    if ($debug and defined $detail) {
        $http_body .= <<EOD;
<h2>Detail:</h2>
<pre style="white-space: pre-wrap">@{[html_escape $detail]}</pre>
EOD
    }
    return $self->response($http_body, %headers);
}

# $self->generate_all($output_dir)
sub generate_all {
    my $self = shift;
    my $output_dir = shift
        or croak "generate_all(): \$output_dir is missing ";
    -d $output_dir and -w $output_dir
        or croak "generate_all(): cannot write: $output_dir";
    for my $page ($self->get_all_pages_for_extensions()) {
        eval {
            $self->generate_static($page, $output_dir);
        };
        if ($@) {
            print STDERR "Error: ".$page->path_info.": $@";
        }
    }
}

# $self->generate_static($page, $output_dir)
sub generate_static {
    my $self = shift;
    my $page = shift
        or croak "generate_static(): \$page is missing";
    my $output_dir = shift
        or croak "generate_static(): \$output_dir is missing ";
    -d $output_dir and -w $output_dir
        or croak "generate_static(): cannot write: $output_dir";
    my $template_rule = $self->_get_template_rule($page);
    if ($template_rule) {
        my $sfile_path = canonpath($output_dir.$page->path_info);
        my $sfile_dir = dirname($sfile_path);
        print "$sfile_path", "\n";
        unless (-d $sfile_dir) {
            eval {
                mkpath $sfile_dir;
            };
            $@ and croak "generate_static(): $@";
        }
        if (-e $sfile_path) {
            unlink $sfile_path;
        }
        my $pagedata = $self->_get_pagedata($page, $template_rule);
        open my $fh, '>', $sfile_path
            or croak "generate_static(): $sfile_path: $!";
        print $fh $pagedata->{http_body};
        close $fh;
    }
}


# $self->get_all_pages_for_extensions([$dirname [, $excludes]])
sub get_all_pages_for_extensions {
    my $self = shift;
    my $dirname = shift;
    my $excludes = shift;
    my @pages;
    for my $text_path ($self->_get_all_texts($dirname, $excludes)) {
        for my $extension (@{$self->{valid_extensions}}) {
            my $page = IWiki::Page->new(
                text_dir          => $self->{text_dir},
                valid_extensions  => $self->{valid_extensions},
                default_extension => $self->{default_extension},
                user_ns           => $self->{user_ns},
                cache_dir         => $self->{cache_dir},
                use_cache         => $self->{use_cache},
                text_path         => $text_path,
                extension         => $extension);
            if ($page->is_ok and $self->_get_template_rule($page)) {
                push @pages, $page;
            }
        }
    }
    @pages;
}

# $self->get_all_pages([$dirname [, $excludes]])
sub get_all_pages {
    my $self = shift;
    my $dirname = shift;
    my $excludes = shift;
    my @pages;
    for my $text_path ($self->_get_all_texts($dirname, $excludes)) {
        my $page = IWiki::Page->new(
            text_dir          => $self->{text_dir},
            valid_extensions  => $self->{valid_extensions},
            default_extension => $self->{default_extension},
            user_ns           => $self->{user_ns},
            cache_dir         => $self->{cache_dir},
            use_cache         => $self->{use_cache},
            text_path         => $text_path
        );
        if ($page->is_ok and $self->_get_template_rule($page)) {
            push @pages, $page;
        }
    }
    @pages;
}

# $self->_get_all_texts([$dirname [, $excludes]])
sub _get_all_texts {
    my $self = shift;
    my $text_dir = canonpath($self->{text_dir}.(shift || ''));
    -d $text_dir or croak "_get_all_texts(): $text_dir is not a directory";
    my $excludes = shift || [];

    my @texts;
    my $process = sub {
        return unless -f $_;
        my $path = canonpath($File::Find::name);
        my ($filename, $dir, $ext) = fileparse($path, qr/\.[^\.]+$/);
        return if $ext ne '.txt'
               or grep {$filename eq $_ } @{$excludes};
        push @texts, $path;
    };
    find($process, $text_dir);
    return @texts;
}

1;

