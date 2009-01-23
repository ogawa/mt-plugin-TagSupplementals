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
      or return $ctx->_no_entry_error( 'MT' . $ctx->stash('tag') );
    my @tags = $entry->get_tags;
    scalar @tags;
}

sub tag_last_updated {
    my ( $ctx, $args ) = @_;
    my $tag = $ctx->stash('Tag') or return '';
    my ( %blog_terms, %blog_args );
    $ctx->set_blog_load_context( $args, \%blog_terms, \%blog_args )
      or return $ctx->error( $ctx->errstr );

    my ($e) = MT::Entry->load(
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

sub related_entries {
    my ( $ctx, $args, $cond ) = @_;
    my $entry = $ctx->stash('entry')
      or return $ctx->_no_entry_error( 'MT' . $ctx->stash('tag') );

    my $weight = $args->{weight} || 'constant';
    my $lastn  = $args->{lastn}  || 0;
    my $offset = $args->{offset} || 0;
    $lastn += $offset;

    my %tag_ids;
    foreach ( @{ $entry->get_tag_objects } ) {
        $tag_ids{ $_->id } = 1;
        my @more = MT::Tag->load( { n8d_id => $_->n8d_id || $_->id } );
        $tag_ids{ $_->id } = 1 foreach @more;
    }
    my @tag_ids = keys %tag_ids
      or return '';

    my ( %blog_terms, %blog_args );
    $ctx->set_blog_load_context( $args, \%blog_terms, \%blog_args )
      or return $ctx->error( $ctx->errstr );

    # calculate coocurrence vector
    my %rank;
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

    # sort by entry_id, and then sort by rank
    my @eids = sort { $b <=> $a } keys %rank;
    @eids = sort { $rank{$b} <=> $rank{$a} } @eids;

    my @entries;
    my $i = 0;
    for my $eid (@eids) {
        my $e = MT::Entry->load($eid);
        if ( $e->status == MT::Entry::RELEASE() ) {
            next if $i < $offset;
            push @entries, $e;
            $i++;
            last if $lastn && $i >= $lastn;
        }
    }

    my $res     = '';
    my $tokens  = $ctx->stash('tokens');
    my $builder = $ctx->stash('builder');
    $i = 0;
    for my $e (@entries) {
        local $ctx->{__stash}{entry}         = $e;
        local $ctx->{current_timestamp}      = $e->created_on;
        local $ctx->{modification_timestamp} = $e->modified_on;
        my $out = $builder->build(
            $ctx, $tokens,
            {
                %$cond,
                EntriesHeader => !$i,
                EntriesFooter => !defined $entries[ $i + 1 ],
            }
        );
        return $ctx->error( $ctx->errstr ) unless defined $out;
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
        { %blog_args, }
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

    my @res;
    my $builder = $ctx->stash('builder');
    my $tokens  = $ctx->stash('tokens');
    while ( my $t = $iter->() ) {
        next if $t->is_private || ( $t->id == $tag->id );
        local $ctx->{__stash}{Tag}             = $t;
        local $ctx->{__stash}{tag_count}       = undef;
        local $ctx->{__stash}{tag_entry_count} = undef;
        defined( my $out = $builder->build( $ctx, $tokens ) )
          or return $ctx->error( $ctx->errstr );
        push @res, $out;
    }
    my $glue = $args->{glue} || '';
    join $glue, @res;
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

    my @res;
    my $builder = $ctx->stash('builder');
    my $tokens  = $ctx->stash('tokens');
    while ( my $t = $iter->() ) {
        next if $t->is_private;
        local $ctx->{__stash}{Tag}             = $t;
        local $ctx->{__stash}{tag_count}       = undef;
        local $ctx->{__stash}{tag_entry_count} = undef;
        defined( my $out = $builder->build( $ctx, $tokens ) )
          or return $ctx->error( $ctx->errstr );
        push @res, $out;
    }
    my $glue = $args->{glue} || '';
    join $glue, @res;
}

sub encode_urlplus {
    my $s = $_[0];
    return $s unless $_[1];
    $s =~ s!([^ a-zA-Z0-9_.~-])!uc sprintf "%%%02x", ord($1)!eg;
    $s =~ tr/ /+/;
    $s;
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

    my @res;
    my $builder = $ctx->stash('builder');
    my $tokens  = $ctx->stash('tokens');
    foreach (@tags) {
        local $ctx->{__stash}{'Tag'} = $_;
        local $ctx->{__stash}{tag_count} = undef;
        defined( my $out = $builder->build( $ctx, $tokens, $cond ) )
          or return $ctx->error( $ctx->errstr );
        push @res, $out;
    }
    my $glue = $args->{glue} || '';
    join $glue, @res;
}

1;
