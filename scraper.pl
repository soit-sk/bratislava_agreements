#!/usr/bin/env perl
# Copyright 2014 Michal Špaček <tupinek@gmail.com>

# Pragmas.
use strict;
use warnings;

# Modules.
use Database::DumpTruck;
use Encode qw(decode_utf8);
use English;
use HTML::TreeBuilder;
use LWP::UserAgent;
use POSIX qw(strftime);
use URI;
use URI::QueryParam;
use Time::Local;

# Don't buffer.
$OUTPUT_AUTOFLUSH = 1;

# URL of service.
my $base_uri = URI->new('http://www.bratislava.sk/register/vismo/zobraz_dok.asp?id_org=700026&id_ktg=1086&p1=15332');

# Open a database handle.
my $dt = Database::DumpTruck->new({
	'dbname' => 'data.sqlite', 
	'table' => 'data',
});

# Create a user agent object.
my $ua = LWP::UserAgent->new(
	'agent' => 'Mozilla/5.0',
);

# Get page number.
my $root = get_root($base_uri);
my $div = $root->find_by_attribute('class', 'strlistovani');
my @a = $div->find_by_tag_name('a');
my $pages = $a[-2]->as_text;
print "Pages: $pages\n";
my $page_uri = URI->new($base_uri->scheme.'://'.$base_uri->host.
	$a[-2]->attr('href'));

# For each page.
my $act_page = 1;
while (1) {
	print "Page #$act_page\n";
	my $table = $root->find_by_attribute('class', 'seznam');
	my $tbody = $table->find_by_tag_name('tbody');
	my @tr = $tbody->content_list;
	pop @tr;
	foreach my $tr (@tr) {
		my ($date_td, $td) = $tr->find_by_tag_name('td');
		my $a = $td->find_by_tag_name('strong')->find_by_tag_name('a');
		my @note = $td->find_by_tag_name('div')->content_list;
		my $page_uri = URI->new($base_uri->scheme.'://'.
			$base_uri->host.$a->attr('href'));
		my $db_date = get_db_date($date_td->as_text);

		# Direct link to PDF.
		if ($page_uri->query_param('id_dokumenty')) {
			$dt->insert({
				'Page_id' => undef,
				'Document_id' => $page_uri
					->query_param('id_dokumenty'),
				'Date' => $db_date,
				'Title' => $a->as_text,
				'Note' => $note[0],
				'PDF' => $page_uri->as_string,
			});

		# Subpage.
		} else {
			my $root_one = get_root($page_uri);
			my @pdf = $root_one->find_by_attribute('class',
				'tpdf typsouboru');
			foreach my $pdf (@pdf) {
				my $pdf_a = $pdf->find_by_tag_name('strong')
					->find_by_tag_name('a');
				my $pdf_uri = URI->new($page_uri->scheme.'://'.
					$page_uri->host.$pdf_a->attr('href'));
				$dt->insert({
					'Page_id' => $page_uri->query_param('id'),
					'Document_id' => $pdf_uri
						->query_param('id_dokumenty'),
					'Date' => $db_date,
					'Title' => $a->as_text,
					'Note' => $note[0],
					'PDF' => $pdf_uri->as_string,
				});
			}
		}	
	}

	# Next page.
	if ($act_page >= $pages) {
		last;
	}
	$act_page++;
	$page_uri->query_param('stranka' => $act_page);
	$root = get_root($page_uri);
}

# Get root of HTML::TreeBuilder object.
sub get_root {
	my $uri = shift;
	my $get = $ua->get($uri->as_string);
	my $data;
	if ($get->is_success) {
		$data = $get->content;
	} else {
		die "Cannot GET '".$uri->as_string." page.";
	}
	my $tree = HTML::TreeBuilder->new;
	$tree->parse(decode_utf8($data));
	return $tree->elementify;
}

# Get date for database.
sub get_db_date {
	my $html_date = shift;
	my ($day, $mon, $year) = split m/\./ms, $html_date;
	my $time = timelocal(0, 0, 0, $day, $mon - 1, $year - 1900);
	return strftime('%Y-%m-%d', localtime($time));
}
