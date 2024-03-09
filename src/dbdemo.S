; This is an x64 assembly program, in Intel syntax, for NASM (the Netwide Assembler).
; It implements the four functions required for Question 1 of Assignment 3 of COMP3005A-W24,
; along with "UI" code to read input/directions from the user and send the appropriate commands
; to the database. It uses libpq as its database driver; appropriate .dll files for PostgreSQL
; 16 are provided. This specific program is written for the Microsoft x64 Calling Convention,
; and will not work on other platforms without an emulation layer such as Wine.
; This program may be somewhat hard to understand for someone who is not familiar with assembly.
; I have provided helpful comments to the best of my ability to aid in understanding, but this is
; not intended (nor does it serve as) a replacement for knowing the language. For example, I
; may say a series of instructions is the "function prologue" and not elaborate further---doing
; so would be akin to explaining in detail what an if statement does in Python.
; Comprehensive error handling is present and resources are freed after use to avoid memory leaks.
; 
; This program will try to connect to a database using connection string
;   postgresql://postgres:postgres@127.0.0.1/school
; If you need to modify this for any reason, it's somewhere near the bottom. Just be sure to
; re-assemble and link after.

bits 64
default rel

; Define the import table; symbol resolution will ultimately be performed at link time
extern gets
extern printf
extern puts
extern sprintf
extern PQclear
extern PQconnectdb
extern PQexec
extern PQfinish
extern PQgetvalue
extern PQnfields
extern PQntuples
extern PQresultStatus
extern PQstatus


; Allocate space for global variables
segment .bss
conn  resq 1
user  resb 128
fname resb 128
lname resb 128
email resb 128
date  resb 128
stuid resb 128
query resb 512


segment .text
global main  ; Export main


; The main function - where it all begins
; (this _is_ linked with a CRT, so _start is defined elsewhere.)
; Arguments: present but unused
main:
	; Function prologue (I won't call this out from now on; just ignore it)
	push rbp
	mov  rbp    , rsp
	sub  rsp    , 32
	
	; Connect to the database and store the connection in a global variable
	lea  rcx    , [connstr]
	call PQconnectdb
	mov  [conn] , rax
	
	; Check for errors connecting, if so print a message and exit early
	mov  rcx    , rax
	call PQstatus
	test rax    , rax
	jz   .mainloop
	lea  rcx    , [connerr]
	call puts
	jmp  .done

.mainloop:
	; Prompt and get the desired action from the user
	lea  rcx    , [printnonl]
	lea  rdx    , [userwhat]
	call printf
	lea  rcx    , [user]
	call gets
	
	; Call the appropriate function based on the first character of user input
	; Fall-through to quitting (including for empty input)
	mov  al     , [user]
	cmp  al     , 'g'
	jne  .notg
	call getAllStudents
	jmp  .mainloop
.notg:
	cmp  al     , 'a'
	jne  .nota
	call addStudentUI
	jmp  .mainloop
.nota:
	cmp  al     , 'u'
	jne  .notu
	call updateStudentEmailUI
	jmp  .mainloop
.notu:
	cmp  al     , 'd'
	jne  .notd
	call deleteStudentUI
	jmp  .mainloop
.notd:
	lea  rcx    , [userquit]
	call puts
	
	; Free resources associated with the database connection
	mov  rcx    , [conn]
	call PQfinish
.done:
	; Function epilogue
	xor  rax    , rax
	leave
	ret


; Retrieve all students from the database and print all their fields
; Arguments: none
getAllStudents:
	push rbp
	mov  rbp , rsp
	sub  rsp , 64
	push rbx
	push rsi
	push rdi
	push r12
	
	; Execute the query and store the result ptr in rbx
	mov  rcx , [conn]
	lea  rdx , [getq]
	call PQexec
	mov  rbx , rax
	
	; Check for errors; if one occurred, print a message and exit early
	mov  rcx , rax
	call PQresultStatus
	cmp  rax , 2
	jle  .getgood
	lea  rcx , [getfail]
	call puts
	jmp  .cleanup
	
.getgood:
	; Get the number of tuples into rsi and the number of fields into rdi
	mov  rcx , rbx
	call PQntuples
	mov  rsi , rax
	mov  rcx , rbx
	call PQnfields
	mov  rdi , rax

	; Print a header
	lea  rcx , [gethead]
	call puts

.tpiter:
	; Print the next tuple; start with an empty line, reset the field index (r12)
	lea  rcx , [empty]
	call puts
	xor  r12 , r12
	
	; If we are done printing tuples, exit the loop
	dec  rsi
	jl   .cleanup
	
.fielditer:
	; Print the next field
	mov  rcx , rbx
	mov  rdx , rsi
	mov  r8  , r12
	call PQgetvalue
	lea  rcx , [fieldnonl]
	mov  rdx , rax
	call printf
	
	; Increment the field index (r12); if done with this tuple, move to next
	inc  r12
	cmp  r12 , rdi
	je   .tpiter
	jmp  .fielditer

.cleanup:
	; Free resources associated with the result object
	mov  rcx , rbx
	call PQclear
	
	pop  r12
	pop  rdi
	pop  rsi
	pop  rbx
	leave
	ret


; Ask the user for what values the fields of the new student should take
; Once all information has been gathered appropriately, calls addStudent with
; the appropriate (fully custom! advantages to assembly) calling convention
; No arguments, but does read data from the user
addStudentUI:
	push rbp
	mov  rbp , rsp
	sub  rsp , 32
	
	; Repeat: prompt, read user input, store in appropriate global variable
	lea  rcx , [printnonl]
	lea  rdx , [whatfname]
	call printf
	lea  rcx , [fname]
	call gets
	lea  rcx , [printnonl]
	lea  rdx , [whatlname]
	call printf
	lea  rcx , [lname]
	call gets
	lea  rcx , [printnonl]
	lea  rdx , [whatemail]
	call printf
	lea  rcx , [email]
	call gets
	lea  rcx , [printnonl]
	lea  rdx , [whatdate]
	call printf
	lea  rcx , [date]
	call gets
	
	; Call addStudent with my *custom calling convention* to do the work
	call addStudent
	
	leave
	ret


; Adds a student using the information provided
; Arguments are passed using a custom calling convention, which I can do
; because I'm writing assembly, as follows:
;   1) first_name     : passed in the fname global variable
;   2) last_name      : passed in the lname global variable
;   3) email          : passed in the email global variable
;   4) enrollment_date: passed in the date global variable
; Neither atomic nor thread-safe.
addStudent:
	push rbp
	mov  rbp      , rsp
	sub  rsp      , 56
	push rbx
	
	; Prepare the insertion query via interpolation
	lea  rcx      , [query]
	lea  rdx      , [fmtaddq]
	lea  r8       , [fname]
	lea  r9       , [lname]
	lea  r10      , [email]
	mov  [rsp+32] , r10
	lea  r11      , [date]
	mov  [rsp+40] , r11
	call sprintf
	
	; Execute the insertion query; store result ptr in rbx
	mov  rcx      , [conn]
	lea  rdx      , [query]
	call PQexec
	mov  rbx      , rax
	
	; Check for errors; if any occurred, print a message
	mov  rcx      , rax
	call PQresultStatus
	cmp  rax      , 2
	jle  .addgood
	lea  rcx      , [addfail]
	call puts

.addgood:
	; Free resources associated with the result set
	mov  rcx      , rbx
	call PQclear
	
	pop  rbx
	leave
	ret


; Ask the user for the ID of the student they would like to update,
; and the new email address. Then, call updateStudentEmail to do the work.
; No arguments; does take user input
updateStudentEmailUI:
	push rbp
	mov  rbp , rsp
	sub  rsp , 32
	
	; Repeat: prompt, read user input, store in appropriate global variable
	lea  rcx , [printnonl]
	lea  rdx , [whatstuid]
	call printf
	lea  rcx , [stuid]
	call gets
	lea  rcx , [printnonl]
	lea  rdx , [newemail]
	call printf
	lea  rcx , [email]
	call gets
	
	; Call updateStudentEmail to do the work
	call updateStudentEmail
	
	leave
	ret


; Attempts to update the student with the specified ID to the specified email.
; This can fail if, e.g., no such ID or non-unique email; in such cases a
; message will be printed.
; Arguments are passed using a custom calling convention:
;   1) student_id: passed in the stuid global variable
;   2) new_email : passed in the email global variable
; Neither atomic nor thread-safe.
updateStudentEmail:
	push rbp
	mov  rbp , rsp
	sub  rsp , 40
	push rbx
	
	; Prepare the modification query via interpolation
	lea  rcx , [query]
	lea  rdx , [fmtmodq]
	lea  r8  , [email]
	lea  r9  , [stuid]
	call sprintf
	
	; Execute the modification query; store result ptr in rbx
	mov  rcx , [conn]
	lea  rdx , [query]
	call PQexec
	mov  rbx , rax
	
	; Check for errors; if any occurred, print a message
	mov  rcx , rax
	call PQresultStatus
	cmp  rax , 2
	jle  .modgood
	lea  rcx , [modfail]
	call  puts

.modgood:
	; Free resources associated with the result set
	mov  rcx , rbx
	call PQclear
	
	pop  rbx
	leave
	ret


; Asks the user for the ID of the student they would like to delete,
; then calls deleteStudent to do the work.
; No arguments; does take user input.
deleteStudentUI:
	push rbp
	mov  rbp , rsp
	sub  rsp , 32
	
	; Prompt, read user input, store in appropriate global variable
	lea  rcx , [printnonl]
	lea  rdx , [whatstuid]
	call printf
	lea  rcx , [stuid]
	call gets
	
	; Call deleteStudent to do the work
	call deleteStudent
	
	leave
	ret


; Attempts to delete the student with the specified ID.
; If no student was deleted (perhaps because no student with that ID exists),
; prints an error message.
; Arguments are passed using a custom calling convention:
;   1) student_id: passed in the stuid global variable
; Neither atomic nor thread-safe.
deleteStudent:
	push rbp
	mov  rbp , rsp
	sub  rsp , 40
	push rbx
	
	; Prepare the deletion query via interpolation
	lea  rcx , [query]
	lea  rdx , [fmtdelq]
	lea  r8  , [stuid]
	call sprintf
	
	; Execute the deletion query; store result ptr in rbx
	mov  rcx , [conn]
	lea  rdx , [query]
	call PQexec
	mov  rbx , rax
	
	; Determine how many records were deleted; if 0, print a message
	mov  rcx , rax
	call PQntuples
	test rax , rax
	jnz  .cleanup
	lea  rcx , [delfail]
	call puts
	
.cleanup:
	; Free resources associated with the result set
	mov  rcx , rbx
	call PQclear
	
	pop  rbx
	leave
	ret


; Constant strings - lots of fun SQL and such in here.
; Change connstr below if you need this to connect to another database.
segment .rdata
connstr   db "postgresql://postgres:postgres@127.0.0.1/school", 0
connerr   db "Could not connect to PostgreSQL.", 0
printnonl db "%s", 0
userwhat  db "What would you like to do [enter getAllStudents, ",\
  "addStudent, updateStudentEmail, deleteStudent, or quit]? ", 0
userquit  db "Quitting...", 0
whatfname db "First name? ", 0
whatlname db "Last name? ", 0
whatemail db "Email address? ", 0
whatdate  db "Enrolment date (strict format: yyyy-mm-dd)? ", 0
fmtaddq   db "INSERT INTO students (first_name, last_name, email, ",\
  "enrollment_date) VALUES ('%s', '%s', '%s', '%s');", 0
addfail   db "Could not add a student with this information.", 0
fieldnonl db "'%s' ", 0
getq      db "SELECT * FROM students ORDER BY student_id DESC;", 0
getfail   db "Could not get students as an error occurred.", 0
empty     db 0
gethead   db 0xa, 0xd, "Fields: student_id first_name last_name email ",\
  "enrollment_date", 0
whatstuid db "Student ID? ", 0
newemail  db "New email address? ", 0
fmtmodq   db "UPDATE students SET email = '%s' WHERE student_id = %s;", 0
modfail   db "Modifying this student failed as an error occurred (maybe that ",\
  "ID didn't exist).", 0
fmtdelq   db "DELETE FROM students WHERE student_id = %s RETURNING student_id;", 0
delfail   db "No student with that ID exists.", 0