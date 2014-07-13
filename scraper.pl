#!/usr/bin/env perl
# Copyright 2014 Michal Špaček <tupinek@gmail.com>

# Pragmas.
use strict;
use warnings;

# Modules.
use Database::DumpTruck;
use Encode qw(decode_utf8 encode_utf8);
use HTML::TreeBuilder;
use LWP::UserAgent;
use URI;
use URI::QueryParam;

# URL of service.
my $url = URI->new('http://www.bratislava.sk/register/vismo/zobraz_dok.asp?id_org=700026&id_ktg=1086&p1=15332');

# Open a database handle.
my $dt = Database::DumpTruck->new({
	'dbname' => 'data.sqlite', 
	'table' => 'data',
});

# Create a user agent object.
my $ua = LWP::UserAgent->new(
	'agent' => 'Mozilla/5.0',
);

# Get content.
my $get = $ua->get($url->as_string);
my $data;
if ($get->is_success) {
	$data = $get->content;
} else {
	die 'Cannot GET page.';
}

# HTML::TreeBuilder Object.
my $tree = HTML::TreeBuilder->new;

# Parse file.
$tree->parse(decode_utf8($data));

# Get tree.
my $root = $tree->elementify;
my $table = $root->find_by_attribute('class', 'seznam');
my $tbody = $table->find_by_tag_name('tbody');
my @tr = $tbody->content_list;
pop @tr;
foreach my $tr (@tr) {
	my ($date_td, $td) = $tr->find_by_tag_name('td');
	my $a = $td->find_by_tag_name('strong')->find_by_tag_name('a');
	my @note = $td->find_by_tag_name('div')->content_list;
	my $page_url = URI->new($url->scheme.'://'.$url->host.$a->attr('href'));

	# TODO Get subpage $page_url->as_string,

	# Insert.
	$dt->insert({
		'Document id' => $page_url->query_param('id'),
		# TODO Date.
		'Date' => $date_td->as_text,
		'Title' => $a->as_text,
		'Note' => $note[0],
	});

	# TODO Paging.
}
