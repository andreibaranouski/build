#!/usr/bin/perl

use warnings;
#use strict;
$|++;

use File::Basename;
use Cwd qw(abs_path);
BEGIN
    {
    $THIS_DIR = dirname( abs_path($0));    unshift( @INC, $THIS_DIR );
    }

my $URL_ROOT='http://factory.hq.couchbase.com:8080';

use Getopt::Std;

my $usage = "\nuse:  $0 -j job_name -p param -v new_value\n\n";

use LWP::UserAgent;
my $ua = LWP::UserAgent->new;
$ua->timeout(10);
$ua->env_proxy;

use XML::Simple qw(:strict);
my $xml = XML::Simple->new();

my ($job_name, $param, $new_val);

my $DEBUG = 0;
use Data::Dumper;


my ($jenkins_user, $jenkins_api_token) = ('self.jenkins', '871e176226f645f2011fd50c5cb1a1eb');
my $myProperties = 'fake_root_for_XMLin';

############                        get_config ( <job_name> )
#          
#                                   returns config file contents if successful,
#
#                                   else returns 0
sub get_config
    {
    my ($job) = @_;
    my ($req, $config);
    my ($begin_str_parms, $endof_str_parms) = (0,0);
    my ($before_string_params, $string_params, $after_string_params) = ("", "", "");
    
    my $request_url  = $URL_ROOT .'/job/'. $job .'/config.xml';
    if ($DEBUG)  { print STDERR "\nrequest: $request_url\n\n"; }
    $request = HTTP::Request->new(GET => $request_url);
    $request->authorization_basic($jenkins_user, $jenkins_api_token);
    my $response = $ua->request($request);
    if ($DEBUG)  { print STDERR "respons: ".Dumper($response)."\n\n";  }
 
    if (! $response->is_success)
        {
        if ($response->status_line =~ '404')  { return(0); }
        die $response->status_line;
        }
    $config = $response->content;
    my @lines = split(/\n/, $config);
    foreach my $line (@lines)
        {
        if ($line =~ '<hudson.model.StringParameterDefinition' )  { $begin_str_parms = 1;  $endof_str_parms = 0; }
        if ($line =~ '</hudson.model.StringParameterDefinition')  { $endof_str_parms = 1;  $string_params .= $line."\n";  next; }
        if (! $begin_str_parms)  { $before_string_params .= $line."\n";  next; }
        if (  $endof_str_parms)  { $after_string_params  .= $line."\n";  next; }
        $string_params .= $line."\n";
        }
    $string_params = '<'.$myProperties.'>'."\n".$string_params.'</'.$myProperties.'>';
    return ($before_string_params, $string_params, $after_string_params);
    }

############                        put_config ( <job_name>, <config_file_string> )
#          
#                                   returns config file contents if successful,
#
#                                   else returns 0
sub put_config
    {
    my ($job, $config) = @_;    if ($DEBUG)  { print STDERR "putting config:\n$config\n"; }

    my $request_url  = $URL_ROOT .'/job/'. $job .'/config.xml';
    if ($DEBUG)  { print STDERR "\nrequest: $request_url\n\n"; }
    $request = HTTP::Request->new(POST => $request_url);
    $request->authorization_basic($jenkins_user, $jenkins_api_token);
  # $request->content_type('text/plain');
    $request->content($config);
    my $response = $ua->request($request);
    
    if ($response->is_success)
        {
        $config = $response->content;
        return $config;
        }
    else
        {
        if ($response->status_line =~ '404')  { return(0); }
        my $ERROR = $response->status_line;
        die "$ERROR\n";
    }   }


########################            S T A R T   H E R E

my %options=();
getopts("j:p:v:",\%options);

if  ( defined $options{j} && defined $options{p} && defined $options{v} )
    {
    $job_name  = $options{j};
    $parm_name = $options{p};
    $new_val   = $options{v};
    }
else
    {
    print STDERR "$usage\n";
    exit  99;
    }
my $delay = 2 + int rand(5.3);
sleep $delay;

my ($config_head, $config_parm, $config_tail) = get_config($job_name);

if ($DEBUG)  { print STDERR "before is:\n\n$config_head\n\n"; }
if ($DEBUG)  { print STDERR "after  is:\n\n$config_tail\n\n"; }
if ($DEBUG)  { print STDERR "MIDDLE is:\n\n$config_parm\n\n"; }

my $xmlref = $xml->XMLin($config_parm, ForceArray => ['hudson.model.ParametersDefinitionProperty'], KeyAttr => {} );
if ($DEBUG)  { print STDERR Dumper($xmlref); }

my $paramarray = $$xmlref{'hudson.model.StringParameterDefinition'};

if ($DEBUG)  { print STDERR Dumper($paramarray); }

if ( (ref($paramarray) eq 'ARRAY') )
    {
    if ($DEBUG)  { print STDERR "There are $#$paramarray elements in the paramarray.\n\n"; }
    
    foreach my $ii (0..$#$paramarray)
        {
        my $parm = $$paramarray[$ii];
        if ($DEBUG)  { print STDERR "\n......$ii\n", Dumper($parm); print "\n......\n", $$parm{'name'}; print "\n......\n"; }
        if ($$parm{'name'} eq $parm_name)
            {
            $$paramarray[$ii]{'defaultValue'} = $new_val;
            }
    }   }
else
    {
    if ($DEBUG)  { print STDERR "There is only 1 element in the paramarray, and it's not even an array!\n\n"; }
    
    if ($$paramarray{'name'} eq $parm_name)
        {
        $$paramarray{'defaultValue'} = $new_val;
    }   }

$$xmlref{'hudson.model.StringParameterDefinition'} = $paramarray;

if ($DEBUG)  { print STDERR "\n----------------------------------------------------------------------\n\n"; }
if ($DEBUG)  { print STDERR Dumper($xmlref); }
if ($DEBUG)  { print STDERR "\n======================================================================\n\n$job_name"; }

sleep $delay;

my $new_config = $config_head
                .$xml->XMLout($xmlref, RootName => undef, NoSort => 1, NoAttr => 1, KeyAttr => {}) 
                .$config_tail;

if ($DEBUG) { print STDERR $new_config."\n"; }

put_config($job_name, $new_config);


__END__

