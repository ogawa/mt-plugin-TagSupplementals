# TagSupplementals - Supplemental features for MT 3.3 tags.
#
# $Id$
# This software is provided as-is. You may use it for commercial or 
# personal use. If you distribute it, please keep this notice intact.
#
# Copyright (c) 2006 Hirotaka Ogawa

package MT::Plugin::TagSupplementals;
use strict;
use MT;
use base qw(MT::Plugin);

use MT::Template::Context;
use MT::Entry;
use MT::Tag;
use MT::ObjectTag;

my $plugin;

BEGIN {
    our $VERSION = '0.01';
    $plugin = __PACKAGE__->new({
	name => 'TagSupplementals Plugin',
	description => 'A plugin for providing supplemental features for MT 3.3 tags.',
	doc_link => 'http://as-is.net/wiki/TagSupplementals_Plugin',
	author_name => 'Hirotaka Ogawa',
	author_link => 'http://profile.typekey.com/ogawa/',
	version => $VERSION,
    });
    MT->add_plugin($plugin);
    MT::Template::Context->add_tag(EntryTagsCount => \&entry_tags_count);
    MT::Template::Context->add_container_tag(RelatedEntries => \&related_entries);
}

sub entry_tags_count {
    my $ctx = shift;
    my $entry = $ctx->stash('entry')
	or return $ctx->_no_entry_error('MT' . $ctx->stash('tag'));
    my @tags = $entry->get_tags;
    scalar @tags;
}

sub related_entries {
    my ($ctx, $args, $cond) = @_;
    my $entry = $ctx->stash('entry')
	or return $ctx->_no_entry_error('MT' . $ctx->stash('tag'));

    my $lastn = $args->{lastn} || 0;

    my $entry_id = $entry->id;
    my $blog_id = $entry->blog_id;
    my @tags = MT::Tag->load(undef, {
	sort => 'name',
	join => [ 'MT::ObjectTag', 'tag_id', {
	    object_id => $entry_id,
	    blog_id => $blog_id,
	    object_datasource => MT::Entry->datasource,
	}, {
	    unique => 1,
	} ] })
	or return '';
    my %tag_ids;
    foreach (@tags) {
	$tag_ids{$_->id} = 1;
	my @more = MT::Tag->load({ n8d_id => $_->n8d_id ? $_->n8d_id : $_->id });
	$tag_ids{$_->id} = 1 foreach @more;
    }
    my @tag_ids = keys %tag_ids;

    my %count;
    if (MT::Object->driver->can('count_group_by')) {
	my $iter = MT::ObjectTag->count_group_by({
	    blog_id => $blog_id,
	    tag_id => \@tag_ids,
	    object_datasource => MT::Entry->datasource,
	}, {
	    group => ['object_id'],
	});
	while (my ($count, $object_id) = $iter->()) {
	    $count{$object_id} = $count;
	}
    } else {
	my $iter = MT::ObjectTag->load_iter({
	    blog_id => $blog_id,
	    tag_id => \@tag_ids,
	    object_datasource => MT::Entry->datasource,
	});
	while (my $otag = $iter->()) {
	    $count{$otag->object_id}++;
	}
    }
    delete $count{$entry_id};

    my @eids = sort { $b <=> $a } keys %count;
    @eids = sort { $count{$b} <=> $count{$a} } @eids;

    my @entries;
    my $i = 0;
    foreach (@eids) {
	my $e = MT::Entry->load($_);
	push @entries, $e if $e->status == MT::Entry::RELEASE();
	last if $lastn && $i++ >= $lastn;
    }

    my $res = '';
    my $tokens = $ctx->stash('tokens');
    my $builder = $ctx->stash('builder');
    $i = 0;
    for my $e (@entries) {
	local $ctx->{__stash}{entry} = $e;
	local $ctx->{current_timestamp} = $e->created_on;
	local $ctx->{modification_timestamp} = $e->modified_on;
	my $out = $builder->build($ctx, $tokens, {
	    %$cond,
	    EntriesHeader => !$i,
	    EntriesFooter => !defined $entries[$i+1],
	});
	return $ctx->error($ctx->errstr) unless defined $out;
	$res .= $out;
	$i++;
    }
    $res;
}
