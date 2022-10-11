#!/bin/sh

NAME=blog
USER=pgsql

BIN=/usr/local/bin/
MEDIR=`cd $(dirname ${0}) && pwd`
DUMPDIR=${MEDIR}/db/dump

init()
{
  if [ -z ${1} ]; then
    echo "USAGE> ./${NAME}_ctrl init [deproy path]"
    exit 1
  fi

  create

  DEPROY=`cd ${1} && pwd`
  echo "DEPROY: ${DEPROY}"

  SETTING=${MEDIR}/setting.rb
  if [ ! -e ${SETTING} ]; then
    echo "DBName = '${NAME}'" > ${SETTING}
    echo "DBUser = '${USER}'" >> ${SETTING}
    echo "RootPath = '/$(basename ${DEPROY})'" >> ${SETTING}
  fi

  if [ ! -e ${DEPROY}/index.rb ];       then ln -s ${MEDIR}/blog.rb        ${DEPROY}/index.rb; fi
  if [ ! -e ${DEPROY}/blog.css ];       then ln -s ${MEDIR}/blog.css       ${DEPROY}/; fi
  if [ ! -e ${DEPROY}/template.rhtml ]; then ln -s ${MEDIR}/template.rhtml ${DEPROY}/; fi
  if [ ! -e ${DEPROY}/admin ];          then ln -s ${MEDIR}/admin          ${DEPROY}/; fi
}

create()
{
	${BIN}createdb -U ${USER} ${NAME} --encoding=UTF-8 --locale=ja_JP.UTF-8 --template=template0
	${BIN}psql -U ${USER} ${NAME} -f ${MEDIR}/db/create.sql
}

dump()
{
	mkdir -p ${DUMPDIR}

	${BIN}pg_dump -U ${USER} -Fc -f ${DUMPDIR}/${NAME}`date +%Y%m%d` ${NAME}
}

restore()
{
	${BIN}dropdb -U ${USER} ${NAME}
	${BIN}createdb -U ${USER} ${NAME} --encoding=UTF-8 --locale=ja_JP.UTF-8 --template=template0
	${BIN}pg_restore -U ${USER} -d ${NAME} ${DUMPDIR}/${1}
}

case "$1" in
  init)
    init $2
    ;;
  create)
    create
    ;;
  dump)
    dump
    ;;
  restore)
    if [ -z "$2" ]; then
      echo "need dumpfile name."
    fi
    restore $2
    ;;
  *)
    echo "Syntax Error: ${NAME}_ctrl [create|dump|restore]"
    ;;
esac
