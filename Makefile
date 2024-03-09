.DEFAULT_GOAL := bin/dbdemo.exe

obj/dbdemo.o : src/dbdemo.S
	@if not exist obj mkdir obj
	nasm -f win64 -o $@ $<

bin/dbdemo.exe : obj/dbdemo.o lib/libpq.lib
	gcc -o $@ $< lib/libpq.lib

.PHONY: run
run : bin/dbdemo.exe
	bin/dbdemo.exe

.PHONY: clean
clean :
	rd /q /s obj