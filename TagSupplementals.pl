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
use MT::Promise qw(force);

our $HAVE_MT_XSEARCH = 0;

my $plugin;

BEGIN {
    our $VERSION = '0.06';

    eval { require MT::XSearch; $HAVE_MT_XSEARCH = 1 };
    if ($HAVE_MT_XSEARCH) {
	MT::XSearch->add_search_plugin('TagSupplementals', {
	    label => 'Tag Search',
	    description => 'Tag Search plugin for MT-XSearch',
	    on_execute => \&xsearch_on_execute,
	    on_stash => \&xsearch_on_stash,
	});
    }

    my $plugin = __PACKAGE__->new({
	name => 'TagSupplementals Plugin',
	description => 'A plugin for providing supplemental "tag" features for MT 3.3+',
	doc_link => 'http://code.as-is.net/wiki/TagSupplementals_Plugin',
	author_name => 'Hirotaka Ogawa',
	author_link => 'http://profile.typekey.com/ogawa/',
	version => $VERSION,
	registry => {
	    tags => {
		block => {
		    RelatedEntries => \&related_entries,
		    RelatedTags => \&related_tags,
		    ArchiveTags => \&archive_tags,
		    SearchTags => \&search_tags,
		    $HAVE_MT_XSEARCH ? (XSearchTags => \&xsearch_tags) : (),
		},
		function => {
		    EntryTagsCount => \&entry_tags_count,
		    TagLastUpdated => \&tag_last_updated,
		    $HAVE_MT_XSEARCH ? (TagXSearchLink => \&tag_xsearch_link) : (),
		},
		modifier => {
		    encode_urlplus => \&encode_urlplus,
		},
	    },
	},
	template_tags => {
	    EntryTagsCount => \&entry_tags_count,
	    TagLastUpdated => \&tag_last_updated,
	    $HAVE_MT_XSEARCH ? (TagXSearchLink => \&tag_xsearch_link) : (),
	},
	container_tags => {
	    RelatedEntries => \&related_entries,
	    RelatedTags => \&related_tags,
	    ArchiveTags => \&archive_tags,
	    SearchTags => \&search_tags,
	    $HAVE_MT_XSEARCH ? (XSearchTags => \&xsearch_tags) : (),
	},
	global_filters => {
	    encode_urlplus => \&encode_urlplus,
	},
    });
    MT->add_plugin($plugin);
}

sub entry_tags_count {
    my $ctx = shift;
    my $entry = $ctx->stash('entry')
	or return $ctx->_no_entry_error('MT' . $ctx->stash('tag'));
    my @tags = $entry->get_tags;
    scalar @tags;
}

sub tag_last_updated {
    my ($ctx, $args) = @_;
    my $tag = $ctx->stash('Tag') or return '';
    my $blog_id = $ctx->stash('blog_id') or return '';

    my ($e) = MT::Entry->load(undef, {
	sort => 'created_on',
	direction => 'descend',
	limit => 1,
	join => [ 'MT::ObjectTag', 'object_id', {
	    tag_id => $tag->id,
	    blog_id => $blog_id,
	    object_datasource => MT::Entry->datasource,
	}, {
	    unique => 1,
	} ] })
	or return '';

    $args->{ts} = $e->created_on;
    MT::Template::Context::_hdlr_date($ctx, $args);
}

sub _object_tags {
    my ($blog_id, $tag_id) = @_;
    my $r = MT::Request->instance;
    my $otag_cache = $r->stash('object_tags_cache:' . $blog_id) || {};
    if (!$otag_cache->{$tag_id}) {
	my @otags = MT::ObjectTag->load({
	    blog_id => $blog_id,
	    tag_id => $tag_id,
	    object_datasource => MT::Entry->datasource,
	});
	$otag_cache->{$tag_id} = \@otags;
	$r->stash('object_tags_cache:' . $blog_id, $otag_cache);
    }
    $otag_cache->{$tag_id};
}

sub related_entries {
    my ($ctx, $args, $cond) = @_;
    my $entry = $ctx->stash('entry')
	or return $ctx->_no_entry_error('MT' . $ctx->stash('tag'));

    my $weight = $args->{weight} || 'constant';
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

    my %rank;
    if ($weight eq 'constant') {
	if (MT::Object->driver->can('count_group_by')) {
	    my $iter = MT::ObjectTag->count_group_by({
		blog_id => $blog_id,
		tag_id => \@tag_ids,
		object_datasource => MT::Entry->datasource,
	    }, {
		group => ['object_id'],
	    });
	    while (my ($count, $object_id) = $iter->()) {
		$rank{$object_id} = $count;
	    }
	} else {
	    my $iter = MT::ObjectTag->load_iter({
		blog_id => $blog_id,
		tag_id => \@tag_ids,
		object_datasource => MT::Entry->datasource,
	    });
	    while (my $otag = $iter->()) {
		$rank{$otag->object_id}++;
	    }
	}
    } elsif ($weight eq 'idf') {
	for my $tag_id (@tag_ids) {
	    my $otags = _object_tags($blog_id, $tag_id);
	    next if scalar @$otags == 1;
	    my $rank = 1 / (scalar @$otags - 1);
	    for my $otag (@$otags) {
		$rank{$otag->object_id} += $rank;
	    }
	}
    }
    delete $rank{$entry_id};

    my @eids = sort { $b <=> $a } keys %rank;
    @eids = sort { $rank{$b} <=> $rank{$a} } @eids;

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

    my $otags = _object_tags($blog_id, $tag->id);
    my @eids = map { $_->object_id } @$otags;

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

sub archive_tags {
    my ($ctx, $args, $cond) = @_;
    my $blog_id = $ctx->stash('blog_id') or return '';
    my $entries = force($ctx->stash('entries')) or return '';

    my @eids = map { $_->id } grep { $_->status == MT::Entry::RELEASE() } @$entries;

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
	next if $t->is_private;
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

sub encode_urlplus {
    my $s = $_[0];
    return $s unless $_[1];
    $s =~ tr/ /+/;
    MT::Util::encode_url($s);
}

sub search_tags {
    my ($ctx, $args, $cond) = @_;

    return '' unless $ctx->stash('search_string') =~ /\S/;
    my $tags = $ctx->stash('search_string');
    my @tag_names = MT::Tag->split(',', $tags);
#    my %tags = map { $_ => 1, MT::Tag->normalize($_) => 1 } @tag_names;
#    my @tags = MT::Tag->load({ name => [ keys %tags ] });
    my @tags = MT::Tag->load({ name => @tag_names });
    return '' unless scalar @tags;

    my @res;
    my $builder = $ctx->stash('builder');
    my $tokens = $ctx->stash('tokens');
    foreach (@tags) {
	local $ctx->{__stash}{'Tag'} = $_;
	local $ctx->{__stash}{tag_count} = undef;
	defined(my $out = $builder->build($ctx, $tokens, $cond))
	    or return $ctx->error($ctx->errstr);
	push @res, $out;
    }
    my $glue = $args->{glue} || '';
    join $glue, @res;
}

sub tag_xsearch_link {
    my ($ctx, $args, $cond) = @_;
    my $tag = $ctx->stash('Tag') or return '';
    my $delimiter = $args->{delimiter} || '';
    my $path = MT::Template::Context->_hdlr_cgi_path($ctx);

    $path . 'mt-xsearch.cgi' . '?blog_id=' . $ctx->stash('blog_id') .
	'&amp;search_key=TagSupplementals' .
	($delimiter ? '&amp;delimiter=' . MT::Util::encode_url($delimiter) : '') .
	'&amp;search=' . MT::Util::encode_url($tag->name);
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
