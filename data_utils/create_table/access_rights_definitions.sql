/*
I'm trying to make a table that gives an official definition of what "Read" access, "Read-Write" access, and "Full" access means in this 
Snowflake account. I want to give that definition in terms of a list of executable GRANT statements with a placeholder for the given
role and Schema.

Roleout makes things simple conceptually by definiting all access roles as "Read", "Read-Write", or "Full". However, its out-of-the-box
definition for those access role types doesn't quite fit what I expect. For example, Roleout's "Read-Write" roles can't run CREATE for
pretty much any kind of object, which is something I want to change.

So let's keep the "Read", "Read-Write", "Full" paradigm but change the definitions of what those role types mean. We'll keep track of 
the official definitions using this table.
*/

