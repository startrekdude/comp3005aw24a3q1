# COMP3005A-W24 Assignment 3, Question 1

A simple application that interacts with a PostgreSQL database. The assignment specification says "write an application in your language of choice", so I chose x64 assembly.

### Demo video

[Here](https://drive.google.com/file/d/17zWXfkUzccISE-PvAPKu8NAwykUOFCqN/view?usp=sharing). Note that while I didn't explicitly demonstrate it in the video, my application works with the full names of functions ("`getAllStudents`"), not *just* the shorthand ("`g`").

### File organization

1. `src/`: the source code of my application
2. `init-scripts/`: `.sql` DDL/DML scripts to initialize the database
3. `lib/`: library files used by my application
4. `bin/`: dependencies used by my application (`libpq` and its own dependencies). My application should be run from this directory, so it can find all of its dependencies.

### Assembling and running

My application targets the Microsoft x64 calling convention; as such, it must be run on Windows or with an emulation layer. If you, dearest marking TA, do not have a Windows box handy, use one of the following options:

1. Use a virtual machine; virtualization software such as [VirtualBox](https://www.virtualbox.org/) is free (and Windows itself comes with a generous evaluation period).
2. There's Windows boxes in the SCS computer lab HP 4125.
3. Carleton offers remote access to Windows boxes via [cuDesktop](https://carleton.ca/cudesktop/).
4. An emulation layer such as [Wine](https://www.winehq.org/) will work fine.

The database server itself can run on any operating system. With that said, I only tested with PostgreSQL version 16.1. As this is the version used for this offering of the course, I expect you to test with this version as well.

Without further ado, here's how to build and run my application:

1. Install [NASM](https://nasm.us/), the Netwide Assembler, and add it to your PATH.
2. Install the x64 build of version 10.3.0 of [TDM-GCC](https://jmeubank.github.io/tdm-gcc/download/) and add it to your PATH (the installer will offer to do so). I don't need a C compiler, but I do need a C runtime and something that knows how to link with it—`gcc` et al serves this role. Be sure to install `mingw32-make`, the build system I use (it's selected by default).
3. (Optional) I like symlinking `mingw32-make` to just `make`, but you don't have to.
4. Run `make run` to assemble, link, and run my application. Or just `make` to assemble and link it, at which point it will live in `bin` as `dbdemo.exe`. `make clean` to clean up after yourself. Pretty simple stuff. Substitute `mingw32-make` for `make` in the commands above if you didn't symlink it.
5. By default, my application assumes that it can connect to a PostgreSQL database server on `127.0.0.1` with username `postgres` and password `postgres` and use a database called `school`. If this is not the case, edit the connection string (Ctrl+F for `connstr`) and rebuild.

If you are unable to install TDM-GCC for whatever reason, [w64devkit](https://github.com/skeeto/w64devkit)'s portable copy of the toolchain should work just fine.

My application depends on `libpq` (the PostgreSQL database driver). I've included all the required `.dll`/`.lib` files to save you the hassle of building or finding them.

### Setting up the database

These steps must be performed before running my application; per the assignment specification, it is designed with a specific schema in mind that must be created.

1. Open pgAdmin 4 and create a new database called `school`.
2. Right-click on the new database node in pgAdmin's tree view and select the "Query Tool".
3. Paste the contents of `init-scripts/init.sql` into the query tool and hit run. This will create the `students` table and add the sample data specified in the assignment specification.

### Explanation of functions

1. `main`: connects to the database server and displays a menu in a loop from which the user can select various actions for the application to perform.
2. `getAllStudents`: retrieves all records from the `students` table and prints them to standard out.
3. `addStudentUI`: asks the user for information about the student to be added, then calls `addStudent` to do the work.
4. `addStudent`: adds a student using the given information; prints a message if an error occurs.
5. `updateStudentEmailUI`: asks the user for the ID of the student to update and the new email address, then calls `updateStudentEmail` to do the work.
6. `updateStudentEmail`: attempts to update the email address of the student with the given ID to the given new email address; if this fails, prints a message.
7. `deleteStudentUI`: asks the user for the ID of the student to delete, then calls `deleteStudent` to do the work.
8. `deleteStudent`: attempts to delete the student with the given ID; if no records are deleted (perhaps because this ID does not exist), prints a message.

As you can see, comprehensive error handling is present.