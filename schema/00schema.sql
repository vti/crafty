DROP TABLE IF EXISTS builds;
CREATE TABLE builds (
 id integer PRIMARY KEY,
 uuid text NOT NULL UNIQUE,
 app text NOT NULL,
 rev text NOT NULL,
 branch text NOT NULL,
 author text NOT NULL,
 message text NOT NULL,
 status char(1) NOT NULL DEFAULT 'N',
 stream varchar(255) NOT NULL DEFAULT '',
 started int NOT NULL,
 finished int NOT NULL DEFAULT 0,
 duration int NOT NULL DEFAULT 0
);
