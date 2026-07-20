# inception

- VM: virtualized hardware. A Virtual Machine is a holr computer. It's a completely separated enviroment with it's kernel.
- container: a isolated process. It's a safe enviroment to run a process. It uses the host machine kernel.
- image: it's imutable and has layers. Adding a layer you can modify and add things to the image. A image is a standardized package that includes all of the files, binaries, libraries, and configurations to run a container.
The image is read-only and shared. Multiple containers can run from the same image simultaneously, each getting its own writable layer on top. So picture one frozen base + N thin writable layers, one per container. Deleting a container removes only its writable layer; the image underneath is untouched.
- Volumes: are persistent data stores for containers, created and managed by Docker. When you create a volume, it's stored within a directory on the Docker host. When you mount the volume into a container, this directory is what's mounted into the container. This is similar to the way that bind mounts work, except that volumes are managed by Docker and are isolated from the core functionality of the host machine.
- Bind mount: When you use a bind mount, a file or directory on the host machine is mounted from the host into a container. By contrast, when you use a volume, a new directory is created within Docker's storage directory on the host machine.
- Service: A service is an abstract definition of a computing resource within an application which can be scaled or replaced independently from other components. Services are backed by a set of containers, run by the platform according to replication requirements and placement constraints. As services are backed by containers, they are defined by a Docker image and set of runtime arguments. All containers within a service are identically created with these arguments.
- Docker daemon: is the background service that manages containers, images, volumes and networks. It's the brain of docker


NOTES:
* NAMED VOLUME STORED IN THE HOST *
- how do you get a genuine named volume to store its data at a host path you picked, when picking the path is normally the bind-mount behaviour? I think I need to choose the path but let the Docker create and manage the persistent data, even if I chose the path and it's in my machine?
- but the place to look is the options you can pass to a named volume's local driver. A named volume isn't as rigid as "Docker always picks /var/lib/docker." The local driver accepts parameters. Research question for you: what parameters does the local volume driver accept, and is there a combination that lets a named volume back onto an arbitrary host directory — while still being declared and managed as a named volume, not a bind mount?
- volume with o:bind - how to explain i'ts not a binded mont >>  it's declared in the volumes: section, so Docker creates it as a named, first-class managed object with its own lifecycle — independent of any service. The o: bind is just the local driver's mechanism for reaching the host path I chose; it doesn't change what the object is. A forbidden bind mount, by contrast, is declared inline on the service, is never a managed object, and vanishes as a concept the moment the service definition goes away. So: the bind is the plumbing; the volume is the object. The subject forbids the inline bind-mount object model, not the bind mechanism.
- The named-volume-to-host-path resolution, in one breath: I declare a named volume in the volumes: section using the default local driver, and pass driver_opts — type: none, device: /home/afontele/data/..., o: bind — so the local driver binds my chosen host directory. It's a genuine managed named volume (visible in docker volume ls, its own lifecycle), and the bind is only the driver's mechanism for reaching the path the subject mandates. It is not a forbidden inline bind mount because that's a different object model entirely.
- One caveat to flag for when you actually implement it: /home/afontele/data (and the subdirectories for each volume) has to exist on the host before you up, because the bind can't point at nothing. Where might you create those directories so it happens automatically every time? Hold that question for the Makefile phase — it's a natural fit there.

* DAEMON *
- daemonizes: it does a little dance where the process you launched forks a background copy, hands the real work to that background copy, and then the original process you started exits.
- daemon is: a process that detaches from your terminal and runs in the background, leaving you your shell back.
- In a container, the service must run in the foreground as PID 1, so that the container's lifecycle is tied to the service actually running — not to a decoy process. Like taht, if the service crashes, PID 1 wakes up and the container learns about the crash and can restart.


* NGINX *
- NGINX is is a web server: a program that listens on a network port, receives HTTP(S) requests, and sends back responses. 
- For this project, NGINX plays two roles at once:
	- A TLS terminator — it's the thing that speaks HTTPS to the outside world, holds the certificate, and handles the encryption.
	- A reverse proxy — it doesn't generate your WordPress pages itself. It receives the request and forwards it to another process, then relays the answer back. (receives requests from users - foward them to PHP-FPM - returns the respose to users)
- Why use php-fpm?
	- Whats the difference between html and php?
		- html: it's a markup language — it's just text that describes the structure of a page (headings, paragraphs, links). The browser reads it and draws the page. It's static: the file sitting on disk is the final answer.
		- php: is a programming language — it's code that has to be executed to produce output. A .php file on disk is not the answer yet; it's a set of instructions that, when run, generates HTML.
	- HTML is a static file NGINX can send directly. PHP is code that must be executed, and NGINX has no PHP interpreter, so it forwards the request over FastCGI to php-fpm, which runs the code and returns the generated HTML for NGINX to relay back."
- how does NGINX know what to forward?
	- because you told it to, in the config. 
- KEY: To speak HTTPS, NGINX needs a certificate and a private key. Since login.42.fr isn't a real registered domain, you can't get a certificate from a real authority — you'll generate a self-signed one yourself (the tool for this is OpenSSL). The browser will warn that it's untrusted, and that's expected and fine for this project.

* BUILD CONTEXT *
- The build context is a host-side directory that Docker packages up and sends to the daemon before the build starts. COPY source paths are resolved relative to that.
- Buld context is different from: The container's filesystem root is /, and it comes from the base image. COPY destination paths are resolved relative to that.