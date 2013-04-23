# TagSupplementalsプラグイン

「タグ」機能を追加・拡張するプラグイン。

## 更新履歴

 * 0.01(2006-06-08):
   * 公開。
 * 0.02(2006-06-18):
   * MTRelatedEntriesコンテナタグでlastnオプション指定時にリストされるエントリー数に誤りがある問題の修正。
   * MTRelatedTagsコンテナタグの追加。
   * MT-XSearchサポートの追加。
   * MTXSearchTagsコンテナタグ、MTTagXSearchLinkタグの追加。
 * 0.03(2006-08-11):
   * encode_urlplusグローバルフィルタを追加。
   * 現在のタグが最後に使われた時刻を表示するMTTagLastUpdated変数タグを追加。
   * MT-Searchで検索されたタグのリストを表示するMTSearchTagsコンテナタグを追加。
 * 0.04(2006-09-06):
   * MTRelatedEntriesコンテナタグにweightオプションを追加。
 * 0.05(2006-09-24):
   * MTArchiveTagsコンテナタグを追加。
 * 0.06(2007-08-22):
   * MT 4.0で動作するように変更。
 * 0.10(2008-07-23 00:56:57 +0900):
   * MT 4.0以降のバージョンのみをサポートするようにしました。MT 3.3ユーザは古いバージョンを使ってください。
   * MTTagLastUpdated/MTRelatedEntries/MTRelatedTags/MTArchiveTagsタグで、"blog_ids"、"include_blogs"、"exclude_blogs"オプションが使えるようになりました。
   * Fix: encode_urlplusモディファイアが正常に動作するようにしました。
   * MTRelatedEntriesタグに"offset"オプションを追加しました。
 * 0.20 (2009-01-26 19:43:25 +0900):
   * MT 4.2以降のバージョンのみをサポートするようにしました。
   * メモリの使用量を抑制しました。
   * メモリキャッシュ、memcachedを使ったキャッシュ機能の追加により高速化を達成しました。
 * 0.22 (2009-04-02 19:17:28 +0900):
   * 性能ロギング用のコードをmt:RelatedEntriesに追加。
   * __invalidate_tag_coocurrence内のバグを修正。
   * mt:RelatedTagsが正常に動作しないバグを修正。
   * MT-XSearchとの組み合わせでまったく使い物にならない問題を修正。

## 概要

Movable Type 3.3でタグ機能がネイティブ対応されましたが、標準で用意されているテンプレートタグだけではTagwire Pluginなどと比較して機能が不足しているため、不便を感じなくはありません。

TagSupplementals Pluginは、MT 3.3の提供するテンプレートタグに加えて「あったらいいな」と思われるテンプレートタグのコレクションを実現します。今のところ以下のテンプレートタグを提供しています。

 * MTEntryTagsCount変数タグ
 * MTRelatedEntriesコンテナタグ
 * MTRelatedTagsコンテナタグ
 * MTArchiveTagsコンテナタグ
 * MTTagLastUpdated変数タグ
 * encode_urlplusグローバルフィルタ
 * MTSearchTagsコンテナタグ(MT-Search用のテンプレート内でのみ利用可能)
 * MTXSearchTagsコンテナタグ(MT-XSearchインストール時のみ利用可能)
 * MTTagXSearchLink変数タグ(MT-XSearchインストール時のみ利用可能)

## インストール方法

プラグインをインストールするには、パッケージに含まれるTagSupplements.plをMovable Typeのプラグインディレクトリにアップロードもしくはコピーしてください。

正しくインストールできていれば、Movable TypeのメインメニューにTagSupplements Pluginが新規にリストアップされます。 

## 追加されるテンプレートタグ・フィルタ

### MTEntryTagsCount変数タグ

現在のエントリーのタグの個数を返す変数タグです。

#### オプション

特になし。

#### 使用例

    <MTEntries>
      Tag Count: <$MTEntryTagsCount$>
    </MTEntries>

### MTRelatedEntriesコンテナタグ

エントリーコンテキスト(MTEntriesの内部、または個別アーカイブ)で関連するタグを持つ他のエントリーをリストするコンテナタグです。関連度が高いエントリーから順にリストします。

#### オプション

 * lastn="N": リストをN個まで表示します。デフォルトではすべて表示します(lastn="0")。
 * weight="constant|idf": 関連度の計算方法を選択します。constantの場合にはタグの出現頻度を考慮せず、重み付けなしで評価します。したがって単に関連するタグの個数が多いエントリーからリストされます。idfの場合にはタグの出現頻度の逆数で重み付けして評価します。したがって一般的には出現頻度の低い(ドキュメントの性質を特徴付ける)タグを共有するエントリーの優先順位が上がります。デフォルトではconstant。

#### 使用例

MTEntriesで最近の10件をリストし、そのそれぞれのエントリーについて関連するエントリーを10件リストするには、以下のように記述します。

    <MTEntries lastn="10">
      <h2><a href="<$MTEntryPermalink$>"><$MTEntryTitle$></a></h2>
      <$MTEntryBody$>
      
      <ul>
        <MTRelatedEntries lastn="10">
          <li><a href="<$MTEntryPermalink$>"><$MTEntryTitle$></a></li>
        </MTRelatedEntries>
      </ul>
      
    </MTEntries>

### MTRelatedTagsコンテナタグ

タグコンテキスト(MTTags、MTEntryTags、MTXSearchTagsの内部)で現在のタグに関連するタグをリストするコンテナタグです。関連するタグとは、少なくとも一つ以上のエントリーで共通に使用されているタグ群のことです。

#### オプション

 * glue="glue": リスト時に''glue''で指定された文字列をタグの間に挿入して表示します。

#### 使用例

各エントリーのタグと、それらに関連するタグをリストアップし、それぞれをTechnorati Tagにリンクするには、以下のように記述します。

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

現在のアーカイブに含まれるエントリーのタグのみをリストするコンテナタグです。このコンテナタグは、カテゴリーアーカイブ、月別アーカイブなどの中で使用できます。

#### Option(s)

 * glue="glue": リスト時に''glue''で指定された文字列をタグの間に挿入して表示します。

#### Example

現在のアーカイブに含まれるエントリーのタグをリストし、それぞれをTechnorati Tagにリンクするには、以下のように記述します。

    <h2>Tags in this archive</h2>
    
    <ul>
    <MTArchiveTags>
      <li><a href="http://www.technorati.com/tag/<$MTTagName encode_url="1"$>" rel="TAG"><$MTTagName$></a></li>
    </MTArchiveTags>
    </ul>

### MTTagLastUpdated変数タグ

タグが最後に追加された日時を表示する変数タグです。

#### オプション

MTEntryDateなどと同様にformat, language, utcオプションが使えます。

#### 使用例

    <ul>
    <MTEntryTags>
      <li><$MTTagName$> (<$MTTagLastUpdated$>)</li>
    </MTEntryTags>
    </ul>

### encode_urlplusフィルタ

encode_urlフィルタの代替として利用できるフィルタです。encode_urlではフィルタ対象となる文字列の空白文字が「%20」に変換されますが、encode_urlplusでは「+」に変換されます。

#### 使用例

以下のようにURL文字列を生成する際にencode_urlフィルタの代わりにencode_urlplusフィルタを使用できます。

    <ul>
      <MTEntryTags>
      <li><a href="http://www.technorati.com/tag/<$MTTagName encode_urlplus="1"$>" rel="TAG"><$MTTagName$></a></li>
      </MTEntryTags>
    </ul>

### MTSearchTagsコンテナタグ

MT-Searchのクエリー文字列として与えられたタグをリストするコンテナタグです。このコンテナタグはMT-Searchのテンプレートの中でのみ利用できます。

#### オプション

 * glue="glue": リスト時に''glue''で指定された文字列をタグの間に挿入して表示します。

#### 使用例

MT-Searchのクエリー文字列として与えられたタグと、それらに関連するタグをリストし、それぞれをTechnorati Tagにリンクするには、以下のように記述します。

    <MTSearchTags>
    <h2><$MTTagName$></h2>
     
    <ul>
      <MTRelatedTags>
      <li><a href="http://www.technorati.com/tag/<$MTTagName encode_url="1"$>" rel="TAG"><$MTTagName$></a></li>
      </MTRelatedTags>
    </ul>
    </MTSearchTags>

### MTXSearchTagsコンテナタグ

このタグを利用するにはMT-XSearchをインストールする必要があります。

MT-XSearchのクエリー文字列として与えられたタグをリストするコンテナタグです。このコンテナタグはMT-XSearchのテンプレートの中でのみ利用できます。

#### オプション

 * glue="glue": リスト時に''glue''で指定された文字列をタグの間に挿入して表示します。

#### 使用例

MT-XSearchのクエリー文字列として与えられたタグと、それらに関連するタグをリストし、それぞれをTechnorati Tagにリンクするには、以下のように記述します。

    <MTXSearchTags>
    <h2><$MTTagName$></h2>
     
    <ul>
      <MTRelatedTags>
      <li><a href="http://www.technorati.com/tag/<$MTTagName encode_url="1"$>" rel="TAG"><$MTTagName$></a></li>
      </MTRelatedTags>
    </ul>
    </MTXSearchTags>

### MTTagXSearchLink変数タグ

このタグを利用するにはMT-XSearchをインストールする必要があります。

MT-XSearchによるタグサーチリンクURLを返す変数タグです。言い換えると、MTTagSearchLinkのMT-XSearch版です。

#### オプション

特になし。

#### 使用例

    <ul>
    <MTEntryTags>
      <li><a href="<$MTTagXSearchLink$>"><$MTTagName$></a>
    </MTEntryTags>
    </ul>

## MT-XSearchの利用

後で書く。

## See Also

## License

This code is released under the Artistic License. The terms of the Artistic License are described at [http://www.perl.com/language/misc/Artistic.html](http://www.perl.com/language/misc/Artistic.html).

## Author & Copyright

Copyright 2006-2009, Hirotaka Ogawa (hirotaka.ogawa at gmail.com)
