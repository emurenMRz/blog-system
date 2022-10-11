# blog-system

自サイトのブログ用途に開発した簡易DMSです。

長年お世話になった[tDiary](https://tdiary.org/)からの移行先として開発したため

* tDiary互換の記事アクセス
* 簡易なログ変換ツールの同梱

のような特徴があります。

CGI動作にのみ対応します。

## Required

* Ruby 3.0.4
* PostgreSQL 12.11

> 記述しているのは開発に使用したバージョンです。必須バージョンではありません。

## Usage

手順は以下の通りです。

0. リポジトリをcloneした後"`blog_ctrl.sh`"を開き、冒頭付近のにある生成するデータベース名と接続用のユーザーを編集します。
	```
	NAME=blog
	USER=pgsql
	```
1. "`./blog_ctrl.sh init [デプロイ先のパス]`"を実行します。

	データベース、設定ファイルを作成し、デプロイ先にシンボリックリンクが生成されます。

2. WEBサーバーでCGIの実行権限などを付与します。

	以下、Apacheでの例です。
	> `/admin`ディレクトリは記事管理画面用ファイル群なので、**必ず**アクセス制限をかけてください。

	```
	<Directory "[デプロイ先のパス]/admin/">
		AuthName     Blog
		AuthType     Basic
		AuthUserFile ./.htpasswd
		Require user ***username***

		AllowOverride None
		Options ExecCGI
		AddHandler cgi-script .rb
		DirectoryIndex index.html
	</Directory>
	<Directory "[デプロイ先のパス]">
		AllowOverride None
		Options ExecCGI FollowSymLinks
		AddHandler cgi-script .rb
		DirectoryIndex index.rb
		Require all granted
		<Files "*.rhtml*">
			Require all denied
		</Files>
	</Directory>
	```

3. `template.rhtml`を必要な形に編集します。
4. URLにアクセスし、動作を確認します。

> 管理画面[`/admin`]はURL直接指定でアクセスします。

## Etc.

`/utility`ディレクトリにはtDiaryから移行する際に使用するログ変換ツールが含まれています。

### tdiary_parser.rb

tDiaryの日記とコメントを抽出しjsonに書き出すツールです。tDiaryのdataディレクトリを指定して実行します。
> tDiaryのdataディレクトリにある"`*.td2`"または"`*.tdc`"ファイルで、一行目に`TDIARY2.01.00`と記述されているものだけに対応しています。
> 記述フォーマットは`Wiki`と`GFM`にのみ対応します。

```
./tdiary_parser.rb [tdiary.confの@data_pathで指定していたパス]
```

完了後、`articles_and_comments.json`が生成されます。

日記の段落ごとに1つの記事として分割されています。分割されると不都合がある内容の場合はtDiary側で編集してから再度本ツールを実行するか、生成されたjsonファイルを編集してください。

### tdiary2db.rb

上記で生成された`articles_and_comments.json`から日記とツッコミをデータベースに登録するツールです。`blog_ctrl.sh init`を実行しデータベースを生成した後に実行します。

```
./tdiary2db.rb
```

完了後、データベースに日記とツッコミが登録されます。
