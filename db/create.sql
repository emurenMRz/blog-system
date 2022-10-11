CREATE TABLE article (
	no INTEGER NOT NULL,
	title TEXT NOT NULL,
	visible BOOLEAN NOT NULL DEFAULT FALSE,
	format TEXT NOT NULL,
	tags JSONB,
	views INTEGER NOT NULL DEFAULT 0,
	body TEXT NOT NULL,
	created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	PRIMARY KEY(created_at,no)
);

CREATE TABLE comment (
	id SERIAL PRIMARY KEY,
	name TEXT NOT NULL,
	mail TEXT,
	visible BOOLEAN NOT NULL DEFAULT FALSE,
	body TEXT NOT NULL,
	created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE tag (
	name TEXT NOT NULL PRIMARY KEY,
	views INTEGER NOT NULL DEFAULT 0
);


--index
CREATE INDEX article_tag_idx
	ON article
	USING GIN (tags);


--update tag list
CREATE OR REPLACE FUNCTION updateTagList_core(in_row RECORD) RETURNS VOID AS $$
DECLARE
	tag_name VARCHAR;
BEGIN
	FOR tag_name IN SELECT * FROM jsonb_array_elements_text(in_row.tags) LOOP
		INSERT INTO tag(name, views) VALUES(tag_name, 0)
			ON CONFLICT(name)
			DO NOTHING;
	END LOOP;
END;
$$ LANGUAGE plpgsql VOLATILE;

CREATE OR REPLACE FUNCTION updateTagList() RETURNS trigger AS $$
BEGIN
	PERFORM updateTagList_core(NEW);
	return NEW;
END;
$$ LANGUAGE plpgsql VOLATILE;

CREATE TRIGGER updateTagList_trigger
	BEFORE INSERT OR UPDATE
	ON article
	FOR EACH ROW
	EXECUTE PROCEDURE updateTagList();


--add article
CREATE OR REPLACE FUNCTION addArticle() RETURNS trigger AS $$
DECLARE
	rows INTEGER;
BEGIN
	IF NEW.no IS NULL THEN
		SELECT A.no INTO rows FROM article AS A WHERE A.created_at::DATE=NEW.created_at::DATE ORDER BY A.no DESC LIMIT 1;
		IF rows IS NULL THEN
			NEW.no = 1;
		ELSE
			NEW.no = rows + 1;
		END IF;
	END IF;

	return NEW;
END;
$$ LANGUAGE plpgsql VOLATILE;

CREATE TRIGGER addArticle_trigger
	BEFORE INSERT
	ON article
	FOR EACH ROW
	EXECUTE PROCEDURE addArticle();


--update article
CREATE OR REPLACE FUNCTION updateArticle() RETURNS trigger AS $$
BEGIN
	IF OLD.body <> NEW.body THEN
		NEW.updated_at = CURRENT_TIMESTAMP;
	END IF;

	return NEW;
END;
$$ LANGUAGE plpgsql VOLATILE;

CREATE TRIGGER updateArticle_trigger
	BEFORE UPDATE
	ON article
	FOR EACH ROW
	EXECUTE PROCEDURE updateArticle();


--utility
CREATE OR REPLACE FUNCTION clearArticleViews() RETURNS VOID AS $$
	UPDATE article SET views=0;
$$ LANGUAGE SQL VOLATILE;


CREATE OR REPLACE FUNCTION initTagList() RETURNS VOID AS $$
DECLARE
	row RECORD;
BEGIN
	DELETE FROM tag;
	FOR row IN SELECT * FROM article LOOP
		PERFORM updateTagList_core(row);
	END LOOP;
END;
$$ LANGUAGE plpgsql VOLATILE;


CREATE OR REPLACE FUNCTION rejectEmptyTagName() RETURNS VOID AS $$
DECLARE
	row RECORD;
	new_tags JSONB;
BEGIN
	CREATE TEMPORARY TABLE temp_target AS
		SELECT O.created_at,O.no,O.tags
		FROM article AS O INNER JOIN(
			SELECT * FROM (
				SELECT created_at, no, jsonb_array_elements_text(O.tags) AS tags
				FROM article AS O
			) AS A WHERE A.tags=''
		) AS B ON O.created_at::DATE=B.created_at::DATE AND O.no=B.no;

	FOR row IN SELECT * FROM temp_target LOOP
		SELECT jsonb_agg(O) INTO new_tags FROM jsonb_array_elements_text(row.tags) AS O WHERE O!='';
		UPDATE article SET tags=new_tags WHERE created_at::DATE=row.created_at::DATE AND no=row.no;
	END LOOP;

	DROP TABLE temp_target;
END;
$$ LANGUAGE plpgsql VOLATILE;


CREATE VIEW article_list AS
	SELECT visible, created_at::DATE, no, title, format, views, tags, updated_at
		FROM article
		ORDER BY created_at DESC, views DESC;


CREATE VIEW tag_usage_ranking AS
	SELECT tags, count(tags)
		FROM (SELECT jsonb_array_elements_text(tags) AS tags FROM article) AS O
		GROUP BY tags
		ORDER BY count DESC, tags;
