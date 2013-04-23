# TagSupplementals Plugin

Supplemental "tag" features for Movable Type 4.2.

## Changes

 * 0.01(2006-06-08):
   * First Release.
 * 0.02(2006-06-18):
   * Fix: MTRelatedEntries container outputs a wrong number of entries, when it uses with "lastn" option.
   * Adds MTRelatedTags container tag.
   * Enables "tag search" with MT-XSearch.
   * MTXSearchTags container tag and MTTagXSearchLink tag.
 * 0.03(2006-08-11):
   * Adds encode_urlplus global filter.
   * Adds MTTagLastUpdated variable tag, which shows the latest date/time the current tag was used.
   * Adds MTSearchTags container tag, which shows the list of tags for MT-Search.
 * 0.04(2006-09-06):
   * Adds weight option to MTRelatedEntries container tag.
 * 0.05(2006-09-24):
   * Adds MTArchiveTags container tag.
 * 0.06(2007-08-22):
   * Now supports MT 4.0.
 * 0.10(2008-07-23 00:56:57 +0900):
   * Now only support MT 4.0 or later.
   * Add "blog_ids", "include_blogs", and "exclude_blogs" options to MTTagLastUpdated/MTRelatedEntries/MTRelatedTags/MTArchiveTags.
   * Fix: encode_urlplus works properly.
   * MTRelatedEntries supports "offset" option.

## Overview

Movable Type support tagging features natively.  But I think it is not so convenient because of the lack of varieties of the features for handling tags.

TagSupplementals Plugin is intended to provide supplemental features, in addition to the standard MT tags for tagging.  And now it provides the following MT tags:

 * mt:EntryTagsCount function tag
 * mt:RelatedEntries block tag
 * mt:RelatedTags block tag
 * mt:ArchiveTags block tag
 * mt:TagLastUpdated function tag
 * encode_urlplus global filter
 * mt:SearchTags block tag
 * mt:XSearchTags block tag
 * mt:TagXSearchLink function tag

## How To Install

 * Download and extract TagSupplementals-_version_.zip file.
 * Upload or copy the contents of "plugins" directory into your "plugins" directory.
 * After proper installation, you will find "TagSupplemental" plugin listed on the "System Plugin Settings" screen.

## Available Template Tags and Filters

### MTEntryTagsCount variable tag

Shows the number of tags which current entry has.

#### Options

Nothing.

#### Examples

    <MTEntries>
      Tag Count: <$MTEntryTagsCount$>
    </MTEntries>

### MTRelatedEntries container tag

A container tag for listing entries *related* to the current entry. MTRelatedEntries calculates ''relevance'' between the current entry and each other entries, based on weighted sum of co-occured tags, and then listed entries which have the highest total ''relevance''s.

This container can only be used in "entry context" which means "the inside of MTEntries" or Individual Archives.

#### Options

 * lastn="N": Shows only ''N'' most related entries. By default, all related entries are displayed.
 * weight="contant|idf": Select weighting scheme. When ''weight'' is "constant", each tag would have a constant weight. So MTRelatedEntries lists entries based on simply the number of common tags between two entries. When "idf", each tag would have a weight of 1/''freq'', where ''freq'' is the number of entries tagged with that tag.
 * glue="glue": If specified, this string is added inbetween each block of the loop.

#### Examples

To list 10 most related entries for the current entry:

    <MTEntries lastn="10">
      <h2><a href="<$MTEntryPermalink$>"><$MTEntryTitle$></a></h2>
      <$MTEntryBody$>
      
      <ul>
        <MTRelatedEntries lastn="10">
          <li><a href="<$MTEntryPermalink$>"><$MTEntryTitle$></a></li>
        </MTRelatedEntries>
      </ul>
      
    </MTEntries>

### MTRelatedTags container tag

A container tag for listing tags *related* to the current tag.  The relationship between tags is defined by how many common *entries* includes them.  This container can only be used in "tag context" which means the inside of MTTags, MTEntryTags, or MTXSearchTags.

#### Option(s)

 * glue="glue": Separates each of the tags with a string specified by "''glue''".  This is useful when you wish to separate the tag names with a comma, for example.

#### Example

To list tags of the entries and their related tags, and to link all of them to Technorati:

    <MTEntries lastn="10">
    <h2><$MTEntryTitle$></h2>
    
    <ul>
      <MTEntryTags>
      <li><a href="http://www.technorati.com/tag/<$MTTagName encode_url="1"$>" rel="TAG"><$MTTagName$></a>
        <ul>
          <MTRelatedTags>
          <li><a href="http://www.technorati.com/tag/<$MTTagName encode_url="1"$>" rel="TAG"><$MTTagName$></a></li>
    
          </MTRelatedTags>
        </ul>
      </li>
      </MTEntryTags>
    </ul>
    
    <$MTEntryBody$>
    </MTEntries>

### MTArchiveTags container tag

A container tag for listing tags of entries included in the current archive.  This container can only be used in dated-based archives and category archives.

#### Option(s)

 * glue="glue": Separates each of the tags with a string specified by "''glue''".  This is useful when you wish to separate the tag names with a comma, for example.

#### Example

To list tags of entries included in the current archive, and to link all of them to Technorati:

    <h2>Tags in this archive</h2>
    
    <ul>
    <MTArchiveTags>
      <li><a href="http://www.technorati.com/tag/<$MTTagName encode_url="1"$>" rel="TAG"><$MTTagName$></a></li>
    </MTArchiveTags>
    </ul>

### MTTagLastUpdated variable tag

Shows the last date the tag added.

#### Option(s)

As well as MTEntryDate, "format", "language", and "utc" options are avaiable.

#### Example

    <ul>
    <MTEntryTags>
      <li><$MTTagName$> (<$MTTagLastUpdated$>)</li>
    </MTEntryTags>
    </ul>

### encode_urlplus global filter

A variation of encode_url filter. First this filter converts whitespaces of the target string into '+'s, and then converts it into URL-safe string.

#### Example

When generating URL strings, encode_urlplus can replace encode_url like as follows:

    <ul>
      <MTEntryTags>
      <li><a href="http://www.technorati.com/tag/<$MTTagName encode_urlplus="1"$>" rel="TAG"><$MTTagName$></a></li>
      </MTEntryTags>
    </ul>

### MTSearchTags container tag

A container tag for listing the query string of MT-Search as tags.  It can only be used in "Search Results" Template.

#### Option(s)

 * glue="glue": Separates each of the tags with a string specified by "''glue''".  This is useful when you wish to separate the tag names with a comma, for example.

#### Example

To list tags given by the query string of MT-Search and their related tags, and to link them to Technorati:

    <MTSearchTags>
    <h2><$MTTagName$></h2>
    
    <ul>
      <MTRelatedTags>
      <li><a href="http://www.technorati.com/tag/<$MTTagName encode_url="1"$>" rel="TAG"><$MTTagName$></a></li>
      </MTRelatedTags>
    </ul>
    </MTSearchTags>

### MTXSearchTags container tag

''This tag requires to install MT-XSearch.''

A container tag for listing the query string of MT-XSearch as tags.  It can only be used in "MT-XSearch" Template.

#### Option(s)

 * glue="glue": Separates each of the tags with a string specified by "''glue''".  This is useful when you wish to separate the tag names with a comma, for example.

#### Example

To list tags given by the query string of MT-XSearch and their related tags, and to link them to Technorati:

    <MTXSearchTags>
    <h2><$MTTagName$></h2>
    
    <ul>
      <MTRelatedTags>
      <li><a href="http://www.technorati.com/tag/<$MTTagName encode_url="1"$>" rel="TAG"><$MTTagName$></a></li>
      </MTRelatedTags>
    </ul>
    </MTXSearchTags>

### MTTagXSearchLink variable tag

''This tag requires to install MT-XSearch.''

A variable tag for the tag search URL by using MT-XSearch.  In short, it is an alternative variable tag of MTTagSearchLink for MT-XSearch.

#### Option(s)

Nothing.

#### Example

    <ul>
    <MTEntryTags>
      <li><a href="<$MTTagXSearchLink$>"><$MTTagName$></a>
    </MTEntryTags>
    </ul>

## MT-XSearch support

TBD

## See Also

## License

This code is released under the Artistic License. The terms of the Artistic License are described at [http://www.perl.com/language/misc/Artistic.html](http://www.perl.com/language/misc/Artistic.html).

## Author & Copyright

Copyright 2006-2009, Hirotaka Ogawa (hirotaka.ogawa at gmail.com)
