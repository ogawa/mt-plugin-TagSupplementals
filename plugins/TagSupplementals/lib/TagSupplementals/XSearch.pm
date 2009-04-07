# $Id$
package TagSupplementals::XSearch;

use strict;
use MT;
use MT::XSearch;

MT::XSearch->add_search_plugin(
    'TagSupplementals',
    {
        label       => 'Tag Search',
        description => 'Tag Search plugin for MT-XSearch',
        on_execute  => \&xsearch_on_execute,
        on_stash    => \&xsearch_on_stash,
    }
);

sub tag_xsearch_link {
    my ( $ctx, $args, $cond ) = @_;
    my $tag = $ctx->stash('Tag') or return '';
    my $delimiter = $args->{delimiter} || '';

    require MT::Template::Context;
    require MT::Util;

    my $path = MT::Template::Context->_hdlr_cgi_path($ctx);

    $path
      . 'mt-xsearch.cgi'
      . '?blog_id='
      . $ctx->stash('blog_id')
      . '&amp;search_key=TagSupplementals'
      . (
        $delimiter ? '&amp;delimiter=' . MT::Util::encode_url($delimiter) : '' )
      . '&amp;search='
      . MT::Util::encode_url( $tag->name );
}

sub xsearch_tags {
    my ( $ctx, $args, $cond ) = @_;

    return '' unless defined $ctx->stash('xsearch_tags');
    my $tags = $ctx->stash('xsearch_tags');
    return '' unless scalar @$tags;

    my @res;
    my $builder = $ctx->stash('builder');
    my $tokens  = $ctx->stash('tokens');
    foreach (@$tags) {
        local $ctx->{__stash}{'Tag'} = $_;
        local $ctx->{__stash}{tag_count} = undef;
        defined( my $out = $builder->build( $ctx, $tokens, $cond ) )
          or return $ctx->error( $ctx->errstr );
        push @res, $out;
    }
    my $glue = $args->{glue} || '';
    join $glue, @res;
}

sub xsearch_on_stash {
    my ( $ctx, $val, $self ) = @_;
    $ctx->stash( 'entry', $val );
    $ctx->{current_timestamp}      = $val->created_on;
    $ctx->{modification_timestamp} = $val->modified_on;
    $ctx->stash( 'xsearch_tags', $self->{xsearch_tags} );
}

sub xsearch_on_execute {
    my ( $args, $self ) = @_;

    my $blog_id = $args->{blog_id} or MT->error('Blog ID is required.');
    my $delimiter  = $args->{delimiter}  || ',';
    my $sort_by    = $args->{sort_by}    || 'created_on';
    my $sort_order = $args->{sort_order} || 'descend';
    my $lastn      = $args->{lastn}      || 0;

    my $tags = $args->{search} or MT->error('Search string is required.');

    require MT::Tag;
    require MT::Entry;
    require MT::ObjectTag;

    my @tag_names = MT::Tag->split( $delimiter, $tags )
      or return [];
    my $tag_count = scalar @tag_names;

    my @tags = MT::Tag->load_by_datasource(
        MT::Entry->datasource,
        {
            is_private => 0,
            $blog_id ? ( blog_id => $blog_id ) : (),
            name => \@tag_names,
        }
    );
    $self->{xsearch_tags} = \@tags;
    my @tag_ids = map { $_->id } @tags;

    my @eids;
    my $iter = MT::ObjectTag->count_group_by(
        {
            blog_id           => $blog_id,
            tag_id            => \@tag_ids,
            object_datasource => MT::Entry->datasource,
        },
        { group => ['object_id'], }
    );

    while ( my ( $count, $object_id ) = $iter->() ) {
        push @eids, $object_id if $count == $tag_count;
    }
    return [] unless scalar @eids;

    my @entries;
    for my $eid (@eids) {
        my $e = MT::Entry->lookup($eid);
        if ( $e && $e->status == MT::Entry::RELEASE() ) {
            push @entries, $e;
        }
    }
    @entries =
      $sort_order eq 'descend'
      ? sort { $b->created_on <=> $a->created_on } @entries
      : sort { $a->created_on <=> $b->created_on } @entries;
    splice( @entries, $lastn ) if $lastn && ( scalar @entries > $lastn );

    \@entries;
}

1;
