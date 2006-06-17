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

our $HAVE_MT_XSEARCH = 0;

my $plugin;

BEGIN {
    our $VERSION = '0.02';
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
    MT::Template::Context->add_container_tag(RelatedTags => \&related_tags);

    eval { require MT::XSearch; $HAVE_MT_XSEARCH = 1 };
    if ($HAVE_MT_XSEARCH) {
	MT::XSearch->add_search_plugin('TagSupplementals', {
	    label => 'Tag Search',
	    description => 'Tag Search plugin for MT-XSearch',
	    on_execute => \&xsearch_on_execute,
	    on_stash => \&xsearch_on_stash,
	});
	MT::Template::Context->add_container_tag(XSearchTags => \&xsearch_tags);
    }
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
	if ($e->status == MT::Entry::RELEASE()) {
	    push @entries, $e;
	    $i++;
	    last if $lastn && $i >= $lastn;
	}
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

sub related_tags {
    my ($ctx, $args, $cond) = @_;
    my $tag = $ctx->stash('Tag') or return '';
    my $blog_id = $ctx->stash('blog_id') or return '';

    my @otags = MT::ObjectTag->load({
	blog_id => $blog_id,
	tag_id => $tag->id,
	object_datasource => MT::Entry->datasource,
    });
    my @eids = map { $_->object_id } @otags;

    my $iter = MT::Tag->load_iter(undef, {
	sort => 'name',
	join => ['MT::ObjectTag', 'tag_id', {
	    blog_id => $blog_id,
	    object_id => \@eids,
	    object_datasource => MT::Entry->datasource,
	}, {
	    unique => 1,
	} ] });

    my @res;
    my $builder = $ctx->stash('builder');
    my $tokens = $ctx->stash('tokens');
    while (my $t = $iter->()) {
	next if $t->is_private || ($t->id == $tag->id);
	local $ctx->{__stash}{Tag} = $t;
	local $ctx->{__stash}{tag_count} = undef;
	local $ctx->{__stash}{tag_entry_count} = undef;
	defined(my $out = $builder->build($ctx, $tokens))
	    or return $ctx->error($ctx->errstr);
	push @res, $out;
    }
    my $glue = $args->{glue} || '';
    join $glue, @res;
}

sub xsearch_tags {
    my ($ctx, $args, $cond) = @_;

    return '' unless defined $ctx->stash('xsearch_tags');
    my $tags = $ctx->stash('xsearch_tags');
    return '' unless scalar @$tags;

    my @res;
    my $builder = $ctx->stash('builder');
    my $tokens = $ctx->stash('tokens');
    foreach (@$tags) {
	local $ctx->{__stash}{'Tag'} = $_;
	local $ctx->{__stash}{tag_count} = undef;
	defined(my $out = $builder->build($ctx, $tokens, $cond))
	    or return $ctx->error($ctx->errstr);
	push @res, $out;
    }
    my $glue = $args->{glue} || '';
    join $glue, @res;
}

sub xsearch_on_stash {
    my ($ctx, $val, $self) = @_;
    $ctx->stash('entry', $val);
    $ctx->{current_timestamp} = $val->created_on;
    $ctx->{modification_timestamp} = $val->modified_on;
    $ctx->stash('xsearch_tags', $self->{xsearch_tags});
}

sub xsearch_on_execute {
    my ($args, $self) = @_;

    my $blog_id = $args->{blog_id} or MT->error('Blog ID is required.');
    my $delimiter = $args->{delimiter} || ',';
    my $sort_by = $args->{sort_by} || 'created_on';
    my $sort_order = $args->{sort_order} || 'descend';
    my $lastn = $args->{lastn} || 0;

    my $tags = $args->{search} or MT->error('Search string is required.');
    my @tag_names = MT::Tag->split($delimiter, $tags)
	or return [];
    my $tag_count = scalar @tag_names;

    my @tags = MT::Tag->load_by_datasource(MT::Entry->datasource, {
	is_private => 0,
	$blog_id ? (blog_id => $blog_id) : (),
	name => \@tag_names,
    });
    $self->{xsearch_tags} = \@tags;
    my @tag_ids = map { $_->id } @tags;

    my @eids;
    if (MT::Object->driver->can('count_group_by')) {
	my $iter = MT::ObjectTag->count_group_by({
	    blog_id => $blog_id,
	    tag_id => \@tag_ids,
	    object_datasource => MT::Entry->datasource,
	}, {
	    group => ['object_id'],
	});
	while (my ($count, $object_id) = $iter->()) {
	    push @eids, $object_id if $count == $tag_count;
	}
    } else {
	my $iter = MT::ObjectTag->load_iter({
	    blog_id => $blog_id,
	    tag_id => \@tag_ids,
	    object_datasource => MT::Entry->datasource,
	});
	my %count;
	while (my $otag = $iter->()) {
	    $count{$otag->object_id}++;
	}
	foreach (keys %count) {
	    push @eids, $_ if $count{$_} == $tag_count;
	}
    }
    return [] unless scalar @eids;

    my @entries;
    map { push @entries, MT::Entry->load($_) } @eids;
    @entries = $sort_order eq 'descend' ?
	sort { $b->created_on <=> $a->created_on } @entries :
	sort { $a->created_on <=> $b->created_on } @entries;
    splice(@entries, $lastn) if $lastn && (scalar @entries > $lastn);

    \@entries;
}

1;
