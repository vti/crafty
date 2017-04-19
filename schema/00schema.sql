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
 started int NOT NULL,
 finished int NOT NULL,
 duration int NOT NULL
);
