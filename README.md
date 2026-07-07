# inception

- VM: virtualized hardware. A Virtual Machine is a holr computer. It's a completely separated enviroment with it's kernel.
- container: a isolated process. It's a safe enviroment to run a process. It uses the host machine kernel.
- image: it's imutable and has layers. Adding a layer you can modify and add things to the image. A image is a standardized package that includes all of the files, binaries, libraries, and configurations to run a container.
The image is read-only and shared. Multiple containers can run from the same image simultaneously, each getting its own writable layer on top. So picture one frozen base + N thin writable layers, one per container. Deleting a container removes only its writable layer; the image underneath is untouched.
- Volumes: are persistent data stores for containers, created and managed by Docker. When you create a volume, it's stored within a directory on the Docker host. When you mount the volume into a container, this directory is what's mounted into the container. This is similar to the way that bind mounts work, except that volumes are managed by Docker and are isolated from the core functionality of the host machine.
- Bind mount: When you use a bind mount, a file or directory on the host machine is mounted from the host into a container. By contrast, when you use a volume, a new directory is created within Docker's storage directory on the host machine.


NOTES:
- how do you get a genuine named volume to store its data at a host path you picked, when picking the path is normally the bind-mount behaviour? I think I need to choose the path but let the Docker create and manage the persistent data, even if I chose the path and it's in my machine?
- but the place to look is the options you can pass to a named volume's local driver. A named volume isn't as rigid as "Docker always picks /var/lib/docker." The local driver accepts parameters. Research question for you: what parameters does the local volume driver accept, and is there a combination that lets a named volume back onto an arbitrary host directory — while still being declared and managed as a named volume, not a bind mount?
