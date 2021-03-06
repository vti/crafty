DROP TABLE IF EXISTS builds;
CREATE TABLE builds (
 id integer PRIMARY KEY AUTOINCREMENT,
 uuid text NOT NULL UNIQUE,
 project text NOT NULL,
 status text NOT NULL DEFAULT 'N',
 pid integer NOT NULL DEFAULT 0,

 rev text NOT NULL,
 branch text NOT NULL,
 author text NOT NULL,
 message text NOT NULL,

 created text NOT NULL DEFAULT '',
 started text NOT NULL DEFAULT '',
 finished text NOT NULL DEFAULT '',

 version integer NOT NULL DEFAULT 1
);
