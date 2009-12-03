#!/usr/bin/perl

# dist.pl
# Copyright (C) 2005-2006 Reflexions Data, LLC
# written by Phil Christensen
#
# $Id$
#
# See LICENSE for details


use strict;
use warnings;

use Cwd;
use Options;

my $current_directory = cwd();
my $DEBUG = 0;

sub load_prefs{
	my %prefs = ();
	if(-e "$current_directory/.distrc"){
		open(PREFS, "<$current_directory/.distrc");
		while(<PREFS>){
			chomp;
			my @pieces = split;
			unless($pieces[0]){
				next;
			}
			
			if($pieces[0] eq 'host'){
				my @hosts =  split(",", $pieces[1]);
				$pieces[1] = \@hosts;
			}
			$prefs{$pieces[0]} = $pieces[1];
		}
		close(PREFS);
	}

	return \%prefs;
}

sub save_prefs{
	my $prefs = shift;
	open(PREFS, ">$current_directory/.distrc");
	foreach my $key (keys %{$prefs}){
		if($key eq 'cvs'){
			next;
		}
		
		if($key eq 'host'){
			$prefs->{$key} = join(',', @{$prefs->{$key}});
		}
		
		my $line = $key . "\t" . $prefs->{$key} . "\n";
		
		if($DEBUG){
			print $line;
		}
		else{
			print PREFS $line;
		}
	}
	close(PREFS);
}

sub safe_system{
	my $command = shift;
	my $failure_string = shift;
	if($DEBUG){
		print "EXEC: $command\n";
	}
	else{
		system($command) == 0 or die("$failure_string: $?");
	}
}

unless(-e "$ENV{HOME}/.dist-exclude"){
	open(EXCLUDE_FILE, ">$ENV{HOME}/.dist-exclude");
	print EXCLUDE_FILE "logs\n";
	print EXCLUDE_FILE "var\n";
	print EXCLUDE_FILE "CVS\n";
	print EXCLUDE_FILE ".svn\n";
	print EXCLUDE_FILE "svn-commit.*\n";
	print EXCLUDE_FILE "*.txt\n";
	print EXCLUDE_FILE "*.zip\n";
	print EXCLUDE_FILE "*.doc\n";
	print EXCLUDE_FILE "*.pdf\n";
	print EXCLUDE_FILE "*.jpg\n";
	print EXCLUDE_FILE "*.gif\n";
	print EXCLUDE_FILE "*.png\n";
	print EXCLUDE_FILE "*.wmv\n";
	print EXCLUDE_FILE "*.tap\n";
	print EXCLUDE_FILE "*.pid\n";
	print EXCLUDE_FILE "*.log\n";
	print EXCLUDE_FILE "system.ini.php\n";
	print EXCLUDE_FILE ".*\n";
	print EXCLUDE_FILE "._*\n";
	print EXCLUDE_FILE "\n";
	close(EXCLUDE_FILE);
}

my $prefs = load_prefs();

my $options = new Options(params => [
									  ['source', 's', $prefs->{'source'}, 'The source directory to distribute.'],
									  ['dest', 'd', $prefs->{'dest'}, 'Where to put the files on the remote machines.'],
									  ['host', 'h', $prefs->{'host'}, 'The hosts to distrubute to.'],
									  ['user', 'u', ($prefs->{'user'} ? $prefs->{'user'} : 'root'), 'The user to connect to the hosts as.'],
									  ['chown', 'o', ($prefs->{'chown'} ? $prefs->{'chown'} : ''), 'Change the ownership of the files to this.'],
									  ['chmod', 'p', ($prefs->{'chmod'} ? $prefs->{'chmod'} : ''), 'Change the file permissions to this.']
									],
 						   flags => [
									  ['svn', 'v', 'Upload only modified SVN status results.'],
									  ['force-save', 'f', 'Save directory prefs, overwriting defaults.'],
									  ['sudo', 'S', 'Use sudo to extract files on the remote server.'],
									  ['ignore', 'i', 'Ignore tar exclude file.'],
									  ['debug', 'D', 'Perform a dry-run and output the actions normally taken.'],
									  ['help', '?', 'Display this usage guide.'],
									]);

$options->get_options();

if($options->get_result('help')){
	$options->print_usage();
	exit();
}

chdir($options->get_result('source'));

my $source = cwd();
my $destination_directory = $options->get_result('dest');
my $source_archive = getlogin(). '-' . time() . '-arch.tgz';

my @hosts = $options->get_result('host');

my $user = $options->get_result('user');
my $sudo = ($options->get_result('sudo') || $prefs->{'sudo'});
my $chmod = $options->get_result('chmod');
my $chown = $options->get_result('chown');

if($options->get_result('debug')){
	$DEBUG = 1;
	print "CURRENT VALUES: \n";
	print "user: $user\ndest: $destination_directory\narch: $source_archive\nsource: $source\n";
	foreach my $host (@hosts){
		print "host: $host\n";
	}
	print "\n";
}

print "Creating tarball...\n";

my $file_list = '';
if(@ARGV){
	$file_list = join(' ', @ARGV);
	if($DEBUG){
		print "File list is: $file_list\n\n";
	}
}
if($options->get_result('svn')){
	$file_list .= ' ' . `svn status | grep '^M' | cut -c 9- - | xargs echo`;
}

if($file_list eq ''){
	$file_list = '*';
}

my $command = "cd \"$source\" ; tar -cz " . ($file_list eq '*' && (! $options->get_result('ignore')) ? '-X ~/.dist-exclude' : '') . " -f /tmp/$source_archive $file_list";
safe_system($command, "Tarball creation failed");

my $sudo_string = '';
if($sudo){
	$sudo_string = 'sudo';
}

foreach my $host (@hosts){
	print "Sending archive to $host...\n";
	safe_system("scp /tmp/$source_archive $user\@$host:/tmp/$source_archive", "Couldn't transfer tarball to host");
	print "Uncompressing and Cleaning up on $host...\n";
	
	my $archive_work = "ssh -t -l $user $host \"$sudo_string tar -m -xz -C$destination_directory -f /tmp/$source_archive";
	$archive_work .= " ; $sudo_string rm -f /tmp/$source_archive";
	if($chown){
		$archive_work .= " ; $sudo_string chown -R $chown $destination_directory/*";
	}
	if($chmod){
		$archive_work .= " ; $sudo_string chmod -R $chmod $destination_directory/*";
	}
	$archive_work .= " ; $sudo_string find $destination_directory -name \"._*\" -exec rm -f \\{\\} \\;\"";
	
	safe_system($archive_work, "Update on host failed");
}

print "Cleaning up...\n";
safe_system("rm /tmp/$source_archive", "Cleanup failed");

if($options->get_result('force-save') || (! -e "$current_directory/.distrc")){
	$prefs->{'source'} = $source;
	$prefs->{'dest'} = $destination_directory;
	$prefs->{'host'} = \@hosts;
	$prefs->{'user'} = $user;
	$prefs->{'sudo'} = ($sudo ? 1 : 0);
	$prefs->{'chmod'} = $chmod;
	$prefs->{'chown'} = $chown;
	save_prefs($prefs);
}

print "Source: $source\n";
print "Last distributed at " . scalar(localtime()) . "\n";
