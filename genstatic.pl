#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

our $VERSION = '0.0.1';

use FindBin;
use lib ("$FindBin::Bin/lib", "$FindBin::Bin/sitelib");
use File::Basename qw/basename/;
use File::Spec::Functions qw/catfile curdir/;
use Getopt::Long qw/GetOptions/;
use IWiki;

our %options;


## arguments

sub show_help {
    my $this_filename = basename $0;
    print <<"EOD";
$this_filename -- generate static files
Usage: $this_filename [options]

Options:
    -h,     --help               show this help.
    -d,     --directory=<string> output directory
    -c,     --config=<string>    config file
EOD
    return 1;
}

our %opts = (
    help => 0,
    directory => '',
    config => '');

unless (GetOptions(\%opts,
        'help',
        'directory=s',
        'config=s')) {
    show_help;
    exit 1;
}

if (@ARGV != 0) {
    show_help;
    exit 1;
}

if ($opts{help}) {
    show_help;
    exit;
}



## main

if ($opts{config} and not -r $opts{config}) {
    print STDERR "cannot read: $opts{config}", "\n";
    exit 1;
}
my $config_file  = $opts{config} || catfile($FindBin::Bin, '.config.pl');
eval {
    -f $config_file and require $config_file;
};
if ($@) {
    print STDERR "fatal error at initialization: $@";
    exit 1;
}


my $output_dir = $opts{directory} || curdir;
unless (-d $output_dir and -w $output_dir) {
    print STDERR "cannot write: $output_dir", "\n";
    exit 1;
}


my $iwiki = IWiki->new(%options);
$iwiki->generate_all($output_dir);


__END__

=head1 SCRIPT NAME

genstatic - generate static files

=head1 SYNOPSIS

perl genstatic.pl <argument>

=head1 DESCRIPTION

...

=head1 OPTIONS

=over 4

=item -h --help

print a help message

=item -d --directory

output directory

=item -c --config

config file

=back

=head1 AUTHOR

Ikuo Ishikawa C<< <i.ishikawa.b06@gmail.com> >>

=head1 LICENSE

The MIT License

Copyright (c) 2010 Ikuo Ishikawa

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

See L<http://www.opensource.org/licenses/mit-license.php>

=head1 SEE ALSO

L<Other::Module>, L<manpage(1)>, F<filename>

=cut

