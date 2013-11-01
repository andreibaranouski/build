#!/bin/perl
# 
############ 
#use strict;
use warnings;

package jenkinsReports;

use Exporter qw(import);
#use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

our $VERSION     = 1.00;
our @ISA         = qw(Exporter);
our @EXPORT      = ();
our @EXPORT_OK   = qw( last_done_sgw_bld last_done_sgw_pkg last_good_sgw_bld last_good_sgw_pkg get_builder );

our %EXPORT_TAGS = ( SYNC_GATEWAY => [qw( &last_done_sgw_bld &last_done_sgw_pkg &last_good_sgw_bld &last_good_sgw_pkg)],
                     DEFAULT      => [qw( &get_builder                                                               )] );

my $DEBUG = 0;   # FALSE

############ 

use jenkinsQuery   qw(:DEFAULT );
use buildbotQuery  qw(:HTML :JSON );

my $installed_URL='http://factory.hq.couchbase.com';
my $run_icon  = '<IMG SRC="' .$installed_URL. '/running_20.gif" ALT="running..." HSPACE="50" ALIGN="LEFT">';
my $done_icon = '&nbsp;';


sub date_from_id
    {
    my ($jobID) = @_;
    my $date_rex = '([0-9-]+)_([0-9]+)-([0-9]+)-([0-9]+)';
    if ($jobID =~ $date_rex)  { return $1.'&nbsp;<SMALL>'."$2:$3:$4".'</SMALL>'; }
    return $jobID;
    }

############                        get_builder ( platform, branch, "build" or "package" )
#          
#                                   returns ( builder )
sub get_builder
    {
    my ($platform, $branch, $type) = @_;
    my  $builder;
    
    if ($type eq 'build')    { $builder = $type."_sync_gateway_".$branch;   }
    if ($type eq 'package')  { $builder = $type."_sync_gateway-".$platform; }
    return($builder);
    }

############                        last_done_sgw_pkg ( platform, branch )
#          
#                                   returns ( build_num, is_build_running, build_date, status )
sub last_done_sgw_pkg
    {
    my ($platform, $branch) = @_;
    my $builder  = get_builder($platform, $branch, "package");
    my ($bldnum, $is_running, $bld_date, $isgood);
   
    if ($DEBUG)  { print STDERR 'DEBUG: running jenkinsQuery::get_json('.$builder.")\n";    }
    my $sumpage = jenkinsQuery::get_json($builder);
    my $len = scalar keys %$sumpage;
    if ($len < 1 )
        {                   if ($DEBUG)  { print STDERR "DEBUG: no builds yet!\n"; }
        $bldnum     = -1;
        $is_running = 0;    # 'TBD';
        $bld_date   = 'no package yet';
        $isgood     = 0;
        return( $bldnum, $is_running, $bld_date, $isgood );
        }
    
    if (! defined( $$sumpage{'builds'} ))
        {
        die "no such field: builds\n";
        }
    my $results_array = $$sumpage{'builds'};
    $len = $#$results_array;
    if ($len < 1)
        {
        if ($DEBUG)  { print STDERR "no build results for $builder\n"; }
        $bldnum     = -1;
        $is_running = 0;    # 'TBD';
        $bld_date   = 'no package yet';
        $isgood     = 0;
        return( $bldnum, $is_running, $bld_date, $isgood );
        }
    my @results_numbers;
    my ($found_bldnum, $found_branch);
    for my $item ( 0 .. $len)  { if ($DEBUG) { print STDERR "array[ $item ] is $$results_array[$item]{'number'}\n"; }
                                               push @results_numbers, $$results_array[$item]{'number'};
                                             }
    @bld_numbers = reverse sort { $a <=> $b } @results_numbers;
    if ($DEBUG)  { print STDERR "DEBUG: bld_numbers: $#bld_numbers\n";   print STDERR "@bld_numbers\n";                      }
    if ($DEBUG)  { for my $NN ( @bld_numbers ) { print STDERR "$NN\n";}  print STDERR "DEBUG: bld_numbers: $#bld_numbers\n"; }
    for my $bnum (@bld_numbers)
        {
        if ($DEBUG) { print STDERR "...checkint $bnum\n"; }
        $bldpage  = jenkinsQuery::get_json($builder.'/'.$bnum);

        if (! defined( $$bldpage{'actions'} ))
            {
            die "no such field: actions\n";
            }
        if (! defined( $$bldpage{'actions'}[0] ))
            {
            die "no such field: actions[0]\n";
            }
        if (! defined( $$bldpage{'actions'}[0]{'parameters'} ))
            {
            die "no such field: actions[0]{parameters}\n";
            }
        for my $pp (0 .. scalar $$bldpage{'actions'}[0]{'parameters'})
            {
            if ($DEBUG)  { print STDERR "pp is $pp\n"; }
            if ($$bldpage{'actions'}[0]{'parameters'}[$pp]{'name'} eq 'REVISION')
                {
                $found_bldnum = $$bldpage{'actions'}[0]{'parameters'}[$pp]{'value'};
                }
            if ($$bldpage{'actions'}[0]{'parameters'}[$pp]{'name'} eq 'GITSPEC')
                {
                $found_branch = $$bldpage{'actions'}[0]{'parameters'}[$pp]{'value'};
                }
            last if ( defined($found_bldnum) && defined($found_branch) );
            }
        if ($DEBUG)  { print STDERR "detected branch: $found_branch\n"; }
        if ($found_branch eq $branch)  { $bldnum = $bnum; last; }
        }
    if (! defined ($bldnum))
        {
        if ($DEBUG)  { print STDERR "no $branch matching builds for $builder\n"; }
        $bldnum     = -1;
        $is_running = 0;    # 'TBD';
        $bld_date   = 'no package yet';
        $isgood     = 0;
        return( $bldnum, $is_running, $bld_date, $isgood );
        }
    if (! defined ($found_bldnum))
        {
        $found_bldnum = '<I>bld&nbsp;'.$bldnum.'</>';
        }
    if ($DEBUG)  { print STDERR "bldnum is: $bldnum\n"; }
    
    my $result  = jenkinsQuery::get_json($builder.'/'.$bldnum);
    $is_running = 'unknown';
    if (defined( $$result{'building'} ))  { $is_running = ($$result{'building'} ne 'false');   if ($DEBUG) {print STDERR "setting is_running to $$result{'building'}\n";}}
 
    $bld_date   = 'unknown';
    $dat_rex    = '([0-9-]+)_([0-9-]+)';
    if (defined( $$result{'id'}       ))  { $bld_date   =  date_from_id( $$result{'id'} );      if ($DEBUG) {print STDERR "setting bld_date   to $bld_date\n"; }}

    $isgood     = 'unknown';
    if (defined( $$result{'result'}   ))  { $isgood     = ($$result{'result'}   eq 'SUCCESS'); if ($DEBUG) {print STDERR "setting isgood     to :$$result{'result'}:\n";}}
 
    return( $found_bldnum, $is_running, $bld_date, $isgood );
    }



############                        last_done_sgw_bld ( platform, branch )
#          
#                                   returns ( build_num, is_build_running, build_date, status )
sub last_done_sgw_bld
    {
    ($platform, $branch) = @_;
    my $builder  = get_builder($platform, $branch, "build");
    my $property = 'lastCompletedBuild';
    last_sync_gateway($platform, $branch, $builder, $property);
    }
   
############                        last_good_sgw_bld ( platform, branch )
#          
#                                   returns ( build_num, is_build_running, build_date, status )
sub last_good_sgw_bld
    {
    ($platform, $branch) = @_;
    my $builder  = get_builder($platform, $branch, "build");
    my $property = 'lastSuccessfulBuild';
    last_sync_gateway($platform, $branch, $builder, $property);
    }
   



############                        last_sync_gateway ( platform, branch, job_name, property )
#          
#                                       my $builder  = "build_sync_gateway_$branch";
#          
#                                   returns ( build_num, is_build_running, build_date, status )
#          
#                                       of
sub last_sync_gateway
    {
    my ($platform, $branch, $job_name, $property) = @_;
    my ($bldnum, $is_running, $bld_date, $isgood);
   
    if ($DEBUG)  { print STDERR 'DEBUG: running jenkinsQuery::get_json('.$job_name.")\n";    }
    my $sumpage = jenkinsQuery::get_json($job_name);
    my $len = scalar keys %$sumpage;
    if ($len < 1 )
        {                   if ($DEBUG)  { print STDERR "DEBUG: no builds yet!\n"; }
        $bldnum     = -1;
        $is_running = 'TBD';
        $bld_date   = 'no build yet';
        $isgood     = 0;
        return( $bldnum, $is_running, $bld_date, $isgood );
        }
    
    if (! defined( $$sumpage{$property} ))
        {
        die "no such build:  $property\n";
        }
    if (! defined( $$sumpage{$property}{'number'} ))
        {
        die "no such build:  $property\n";
        }
    $bldnum = $$sumpage{$property}{'number'};
    if ($DEBUG)  { print STDERR "bldnum is: $bldnum\n"; }
    
    my $result  = jenkinsQuery::get_json($job_name.'/'.$bldnum);
    $is_running = 'unknown';
    if (defined( $$result{'building'} ))  { $is_running = ($$result{'building'} ne 'false');   if ($DEBUG) {print STDERR "setting is_running to $$result{'building'}\n";}}
 
    $bld_date   = 'unknown';
    if (defined( $$result{'id'}       ))  { $bld_date   =  date_from_id( $$result{'id'} );     if ($DEBUG) {print STDERR "setting bld_date   to $bld_date\n"; }}

    $isgood     = 'unknown';
    if (defined( $$result{'result'}   ))  { $isgood     = ($$result{'result'}   eq 'SUCCESS'); if ($DEBUG) {print STDERR "setting isgood     to :$$result{'result'}:\n";}}
 
    return( $bldnum, $is_running, $bld_date, $isgood );
    }



1;
__END__
