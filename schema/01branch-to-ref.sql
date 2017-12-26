alter table builds add column ref text not null default '';
update builds set ref = branch;

ALTER TABLE builds RENAME to builds_backup;

CREATE TABLE builds (
 id integer PRIMARY KEY AUTOINCREMENT,
 uuid text NOT NULL UNIQUE,
 project text NOT NULL,
 status text NOT NULL DEFAULT 'N',
 pid integer NOT NULL DEFAULT 0,

 rev text NOT NULL,
 ref text NOT NULL,
 author text NOT NULL,
 message text NOT NULL,

 created text NOT NULL DEFAULT '',
 started text NOT NULL DEFAULT '',
 finished text NOT NULL DEFAULT '',

 version integer NOT NULL DEFAULT 1
);

INSERT INTO builds SELECT id, uuid, project, status, pid, rev, ref, author, message, created, started, finished, version FROM builds_backup;
