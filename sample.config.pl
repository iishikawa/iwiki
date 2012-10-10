# sample.config.pl
# vim: set ft=perl :

use utf8;
use XML::LibXSLT;

# show debugging messages on error
#$main::options{debug}         = 1;

# directory where text files are placed
#$main::options{text_dir}      = "/path/to/text_dir";

# directory where XSLT templates are placed
#$main::options{template_dir}  = "/path/to/template_dir";

# cache directory
#$main::options{cache_dir}     = "/path/to/cache_dir";

# cache XSLT results
#$main::options{use_cache}     = 0;

# define which template will be used
#$main::options{rules} = [
#    {
#        match_path_info => qr{(?:/.+\.html|/)\z},
#        template        => 'default.xsl',
#    }, # default.xsl is used when PATH_INFO matches the regular expression
#];

# parameters passed to XSLT
#$main::options{xslt_params} = {
#    mail     => 'yourmail@example.org',
#    author   => 'Your Name',
#    homepage => "http://$ENV{SERVER_NAME}$ENV{SCRIPT_NAME}",
#};

# namespace used in text files' meta data section
#$main::options{user_ns} = {
#    rdf     => "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
#    dcterms => "http://purl.org/dc/terms/",
#    xhv     => "http://www.w3.org/1999/xhtml/vocab#",
#    ex      => "http://example.org/ns#",
#};

# list of valid extensions
#$main::options{valid_extensions} = [qw/.html/];

# default extension
#$main::options{default_extension} = '.html';


# define XSLT function
# ex:localtime()
#XML::LibXSLT->register_function($main::options{user_ns}{ex}, 'localtime',
#    sub { scalar localtime });

1;
