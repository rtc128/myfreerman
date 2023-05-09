create schema if not exists rman;
use rman;
create table backup (
	id int not null primary key auto_increment,
	server_id tinyint not null,
	end_time datetime not null,
	backup_type varchar(1) not null,
	binlog_sequence int
);

create index idx_backup_01 on backup (server_id, backup_type);
