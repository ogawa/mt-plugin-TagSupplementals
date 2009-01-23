# TagSupplementals - Supplemental features for MT 3.3 tags.
#
# $Id$
# This software is provided as-is. You may use it for commercial or
# personal use. If you distribute it, please keep this notice intact.
#
# Copyright (c) 2006-2009 Hirotaka Ogawa

package MT::Plugin::TagSupplementals;
use strict;
use base qw( MT::Plugin );

use MT 4;

our $VERSION = '0.20';

our $HAVE_MT_XSEARCH = 0;
{
    eval { require MT::XSearch; $HAVE_MT_XSEARCH = 1 };
    eval "use TaggSupplementals::XSearch" if $HAVE_MT_XSEARCH;
}

my $plugin = __PACKAGE__->new(
    {
        id   => 'tag_supplementals',
        name => 'TagSupplementals',
        description =>
          'A plugin for providing supplemental "tag" features for MT4',
        doc_link => 'http://code.as-is.net/public/wiki/TagSupplementals_Plugin',
        author_name => 'Hirotaka Ogawa',
        author_link => 'http://as-is.net/blog/',
        version     => $VERSION,
    }
);
MT->add_plugin($plugin);

sub instance { $plugin }

sub init_registry {
    my $plugin = shift;
    my $pkg    = 'TagSupplementals::';
    $plugin->registry(
        {
            tags => {
                block => {
                    RelatedEntries => $pkg . 'related_entries',
                    RelatedTags    => $pkg . 'related_tags',
                    ArchiveTags    => $pkg . 'archive_tags',
                    SearchTags     => $pkg . 'search_tags',
                    $HAVE_MT_XSEARCH
                    ? ( XSearchTags => $pkg . 'XSearch::xsearch_tags' )
                    : (),
                },
                function => {
                    EntryTagsCount => $pkg . 'entry_tags_count',
                    TagLastUpdated => $pkg . 'tag_last_updated',
                    $HAVE_MT_XSEARCH
                    ? ( TagXSearchLink => $pkg . 'XSearch::tag_xsearch_link' )
                    : (),
                },
                modifier => { encode_urlplus => $pkg . 'encode_urlplus', },
            },
        }
    );
}

1;
