CREATE TABLE builds (
 id integer PRIMARY KEY,
 uuid text NOT NULL UNIQUE,
 app text NOT NULL,
 ref text NOT NULL,
 branch text NOT NULL,
 created int NOT NULL
);
