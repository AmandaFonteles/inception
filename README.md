# inception

- VM: virtualized hardware. A Virtual Machine is a holr computer. It's a completely separated enviroment with it's kernel.
- container: a isolated process. It's a safe enviroment to run a process. It uses the host machine kernel.
- image: it's imutable and has layers. Adding a layer you can modify and add things to the image. A image is a standardized package that includes all of the files, binaries, libraries, and configurations to run a container.
The image is read-only and shared. Multiple containers can run from the same image simultaneously, each getting its own writable layer on top. So picture one frozen base + N thin writable layers, one per container. Deleting a container removes only its writable layer; the image underneath is untouched.
