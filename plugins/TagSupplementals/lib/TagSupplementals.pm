# $Id$
package TagSupplementals;

use strict;
use MT::Template::Context;
use MT::Entry;
use MT::Tag;
use MT::ObjectTag;
use MT::Promise qw( force );

sub entry_tags_count {
    my $ctx   = shift;
    my $entry = $ctx->stash('entry')
      or return $ctx->_no_entry_error();
    scalar $entry->get_tags;
}

sub tag_last_updated {
    my ( $ctx, $args ) = @_;
    my $tag = $ctx->stash('Tag') or return '';
    my ( %blog_terms, %blog_args );
    $ctx->set_blog_load_context( $args, \%blog_terms, \%blog_args )
      or return $ctx->error( $ctx->errstr );

    my $e = MT::Entry->load(
        undef,
        {
            sort      => 'created_on',
            direction => 'descend',
            limit     => 1,
            join      => [
                'MT::ObjectTag',
                'object_id',
                {
                    %blog_terms,
                    tag_id            => $tag->id,
                    object_datasource => MT::Entry->datasource,
                },
                { %blog_args, unique => 1, }
            ]
        }
    ) or return '';

    $args->{ts} = $e->created_on;
    MT::Template::Context::_hdlr_date( $ctx, $args );
}

sub __tag_coocurrence_cache_key {
    my $obj = shift;
    return undef unless $obj->id;
    sprintf "%stag-coocurrence-%d", $obj->datasource, $obj->id;
}

use constant TAG_COOCURRENCE_CACHE_TIME => 7 * 24 * 60 * 60;    ## 1 week

sub __get_tag_coocurrence {
    my ( $entry, $ctx, $args ) = @_;
    return $entry->{__coocurrence} if $entry->{__coocurrence};

    require MT::Memcached;
    my $cache  = MT::Memcached->instance;
    my $memkey = __tag_coocurrence_cache_key($entry);
    if ( my $rank = $cache->get($memkey) ) {
        $entry->{__coocurrence} = $rank;
        return $rank;
    }

    # calculate coocurrence vector (rank)
    my %rank;

    my %tag_ids;
    foreach ( @{ $entry->get_tag_objects } ) {
        $tag_ids{ $_->id } = 1;
        my @more = MT::Tag->load( { n8d_id => $_->n8d_id || $_->id } );
        $tag_ids{ $_->id } = 1 foreach @more;
    }

    if ( my @tag_ids = keys %tag_ids ) {
        my ( %blog_terms, %blog_args );
        $ctx->set_blog_load_context( $args, \%blog_terms, \%blog_args )
          or return $ctx->error( $ctx->errstr );

        my $weight = $args->{weight} || 'constant';
        if ( $weight eq 'constant' ) {
            my $iter = MT::ObjectTag->count_group_by(
                {
                    %blog_terms,
                    tag_id            => \@tag_ids,
                    object_datasource => MT::Entry->datasource,
                },
                { %blog_args, group => ['object_id'], }
            );
            while ( my ( $count, $object_id ) = $iter->() ) {
                $rank{$object_id} = $count;
            }
        }
        elsif ( $weight eq 'idf' ) {
            for my $tag_id (@tag_ids) {
                my @otags = MT::ObjectTag->load(
                    {
                        %blog_terms,
                        tag_id            => $tag_id,
                        object_datasource => MT::Entry->datasource,
                    },
                    \%blog_args
                );
                my $rank = scalar @otags - 1;
                next if $rank < 1;
                $rank = 1 / $rank;
                $rank{ $_->object_id } += $rank foreach @otags;
            }
        }
        delete $rank{ $entry->id };
    }

    $cache->set( $memkey, \%rank, TAG_COOCURRENCE_CACHE_TIME );
    $entry->{__coocurrence} = \%rank;
    \%rank;
}

sub related_entries {
    my ( $ctx, $args, $cond ) = @_;
    my $entry = $ctx->stash('entry')
      or return $ctx->_no_entry_error();
    my $rank = __get_tag_coocurrence( $entry, $ctx, $args )
      or return $ctx->error( $ctx->errstr );
    my %rank = %$rank;

    my $lastn  = $args->{lastn}  || 0;
    my $offset = $args->{offset} || 0;
    $lastn += $offset;

    # sort by entry_id, and then sort by rank
    my @eids = sort { $b <=> $a } keys %rank;
    @eids = sort { $rank{$b} <=> $rank{$a} } @eids;

    my @entries;
    my $i = 0;
    for my $eid (@eids) {
        my $e = MT::Entry->load($eid);
        if ( $e && $e->status == MT::Entry::RELEASE() ) {
            next if $i < $offset;
            push @entries, $e;
            $i++;
            last if $lastn && $i >= $lastn;
        }
    }

    my $res     = '';
    my $glue    = $args->{glue};
    my $tokens  = $ctx->stash('tokens');
    my $builder = $ctx->stash('builder');
    $i = 0;
    for my $e (@entries) {
        local $ctx->{__stash}{entry}         = $e;
        local $ctx->{current_timestamp}      = $e->created_on;
        local $ctx->{modification_timestamp} = $e->modified_on;
        defined(
            my $out = $builder->build(
                $ctx, $tokens,
                {
                    %$cond,
                    EntriesHeader => !$i,
                    EntriesFooter => !defined $entries[ $i + 1 ],
                }
            )
        ) or return $ctx->error( $ctx->errstr );
        return $ctx->error( $ctx->errstr ) unless defined $out;
        $res .= $glue if defined $glue && length($res) && length($out);
        $res .= $out;
        $i++;
    }
    $res;
}

sub related_tags {
    my ( $ctx, $args, $cond ) = @_;
    my $tag = $ctx->stash('Tag') or return '';
    my ( %blog_terms, %blog_args );
    $ctx->set_blog_load_context( $args, \%blog_terms, \%blog_args )
      or return $ctx->error( $ctx->errstr );

    my @otags = MT::ObjectTag->load(
        {
            %blog_terms,
            tag_id            => $tag->id,
            object_datasource => MT::Entry->datasource,
        },
        \%blog_args
    );
    my @eids = map { $_->object_id } @otags;

    my $iter = MT::Tag->load_iter(
        undef,
        {
            sort => 'name',
            join => [
                'MT::ObjectTag',
                'tag_id',
                {
                    %blog_terms,
                    object_id         => \@eids,
                    object_datasource => MT::Entry->datasource,
                },
                { %blog_args, unique => 1, }
            ]
        }
    );

    my $res     = '';
    my $glue    = $args->{glue};
    my $builder = $ctx->stash('builder');
    my $tokens  = $ctx->stash('tokens');
    while ( my $t = $iter->() ) {
        next if $t->is_private || ( $t->id == $tag->id );
        local $ctx->{__stash}{Tag}             = $t;
        local $ctx->{__stash}{tag_count}       = undef;
        local $ctx->{__stash}{tag_entry_count} = undef;
        defined( my $out = $builder->build( $ctx, $tokens ) )
          or return $ctx->error( $ctx->errstr );
        $res .= $glue if defined $glue && length($res) && length($out);
        $res .= $out;
    }
    $res;
}

sub archive_tags {
    my ( $ctx, $args, $cond ) = @_;
    my $entries = force( $ctx->stash('entries') ) or return '';
    my ( %blog_terms, %blog_args );
    $ctx->set_blog_load_context( $args, \%blog_terms, \%blog_args )
      or return $ctx->error( $ctx->errstr );

    my @eids =
      map { $_->id } grep { $_->status == MT::Entry::RELEASE() } @$entries;

    my $iter = MT::Tag->load_iter(
        undef,
        {
            sort => 'name',
            join => [
                'MT::ObjectTag',
                'tag_id',
                {
                    %blog_terms,
                    object_id         => \@eids,
                    object_datasource => MT::Entry->datasource,
                },
                { %blog_args, unique => 1, }
            ]
        }
    );

    my $res     = '';
    my $glue    = $args->{glue};
    my $builder = $ctx->stash('builder');
    my $tokens  = $ctx->stash('tokens');
    while ( my $t = $iter->() ) {
        next if $t->is_private;
        local $ctx->{__stash}{Tag}             = $t;
        local $ctx->{__stash}{tag_count}       = undef;
        local $ctx->{__stash}{tag_entry_count} = undef;
        defined( my $out = $builder->build( $ctx, $tokens ) )
          or return $ctx->error( $ctx->errstr );
        $res .= $glue if defined $glue && length($res) && length($out);
        $res .= $out;
    }
    $res;
}

sub search_tags {
    my ( $ctx, $args, $cond ) = @_;

    return '' unless $ctx->stash('search_string') =~ /\S/;
    my $tags = $ctx->stash('search_string');
    my @tag_names = MT::Tag->split( ',', $tags );

    #    my %tags = map { $_ => 1, MT::Tag->normalize($_) => 1 } @tag_names;
    #    my @tags = MT::Tag->load({ name => [ keys %tags ] });
    my @tags = MT::Tag->load( { name => @tag_names } );
    return '' unless scalar @tags;

    my $res     = '';
    my $glue    = $args->{glue};
    my $builder = $ctx->stash('builder');
    my $tokens  = $ctx->stash('tokens');
    foreach (@tags) {
        local $ctx->{__stash}{'Tag'} = $_;
        local $ctx->{__stash}{tag_count} = undef;
        defined( my $out = $builder->build( $ctx, $tokens, $cond ) )
          or return $ctx->error( $ctx->errstr );
        $res .= $glue if defined $glue && length($res) && length($out);
        $res .= $out;
    }
    $res;
}

sub encode_urlplus {
    my $s = $_[0];
    return $s unless $_[1];
    $s =~ s!([^ a-zA-Z0-9_.~-])!uc sprintf "%%%02x", ord($1)!eg;
    $s =~ tr/ /+/;
    $s;
}

1;
