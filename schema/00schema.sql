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
 pid int NOT NULL DEFAULT 0,

 started text NOT NULL,
 finished text NOT NULL DEFAULT '',
 duration real NOT NULL DEFAULT 0.0
);
