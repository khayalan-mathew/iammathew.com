---
title: Docker Best Practices
author: iammathew
date: 2020-08-30
hero: ./images/hero.png
excerpt: Working with a handful of people together and releasing stuff
---

# Docker Best Practices

## Image Building

### Weird behavior

Lets look at the following docker image:

```dockerfile
FROM ubuntu:latest

RUN rm -rf /usr
```

What does it do:

1. It uses the latest ubuntu image as its base image (either pulls it on build or uses the cache)
2. It runs `rm -rf /usr` inside the container effectively removing the whole `/usr` directory

Now lets build it

```
> docker build . -f Weird.Dockerfile

Sending build context to Docker daemon  506.4kB
Step 1/2 : FROM ubuntu:latest
 ---> 1e4467b07108
Step 2/2 : RUN rm -rf /usr
 ---> Using cache
 ---> 3db792dede18
Successfully built 3db792dede18
Successfully tagged weird:latest
```

Lets look at our freshly built image

```
> docker image ls

REPOSITORY                    TAG                 IMAGE ID            CREATED             SIZE
weird                         latest              3db792dede18        2 minutes ago       73.9MB
ubuntu                        latest              1e4467b07108        2 weeks ago         73.9MB
```

Weird even though we removed a whole directory building our image the size didnt decrease...

The reason why this is the case is how docker images work internally, its literally impossible to decrease a docker image in size by building ontop of it, everything you will do will just increase the size. So how do docker images look like?

### How docker images really look like

I guess for a first glance we can just look at what docker tells us about our newly built image:

```
> docker inspect weird:latest

[
    {
        "Id": "sha256:3db792dede18cc487b4a4f2e6bea09441a96580ad933a209a6664a8f88019feb",
        "RepoTags": [
            "weird:latest"
        ],
        "RepoDigests": [],
        "Parent": "sha256:1e4467b07108685c38297025797890f0492c4ec509212e2e4b4822d367fe6bc8",
        "Comment": "",
        "Created": "2020-08-12T21:23:58.991306511Z",
        "Container": "fe5a333c98486e05f0e666cbb61537c0693e5796e767ef29f9d28f5a15677972",
        "ContainerConfig": {
            "Hostname": "",
            "Domainname": "",
            "User": "",
            "AttachStdin": false,
            "AttachStdout": false,
            "AttachStderr": false,
            "Tty": false,
            "OpenStdin": false,
            "StdinOnce": false,
            "Env": [
                "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"P
            ],
            "Cmd": [
                "/bin/sh",
                "-c",
                "rm -rf /usr"
            ],
            "Image": "sha256:1e4467b07108685c38297025797890f0492c4ec509212e2e4b4822d367fe6bc8",
            "Volumes": null,
            "WorkingDir": "",
            "Entrypoint": null,
            "OnBuild": null,
            "Labels": null
        },
        "DockerVersion": "19.03.12-ce",
        "Author": "",
        "Config": {
            "Hostname": "",
            "Domainname": "",
            "User": "",
            "AttachStdin": false,
            "AttachStdout": false,
            "AttachStderr": false,
            "Tty": false,
            "OpenStdin": false,
            "StdinOnce": false,
            "Env": [
                "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
            ],
            "Cmd": [
                "/bin/bash"
            ],
            "ArgsEscaped": true,
            "Image": "sha256:1e4467b07108685c38297025797890f0492c4ec509212e2e4b4822d367fe6bc8",
            "Volumes": null,
            "WorkingDir": "",
            "Entrypoint": null,
            "OnBuild": null,
            "Labels": null
        },
        "Architecture": "amd64",
        "Os": "linux",
        "Size": 73859057,
        "VirtualSize": 73859057,
        "GraphDriver": {
            "Data": {
                "LowerDir": "/var/lib/docker/overlay2/3224bb80b128bc5ae942f28c2b24c119a8b3933d63ae6e6e8b9b2ef664632964/diff:/var/lib/docker/overlay2/368b18633aa24059c68fdd9e7e71f829be9dcef97155f47f226bdddd000d19d4/diff:/var/lib/docker/overlay2/4186366c68fe0a9a2cec34744a5c6eda300e2fab8a1e8184a1f367cce9a3fa92/diff:/var/lib/docker/overlay2/70b1f1770d0e5dbc64e9d952f53006a5e6399c3a1bb1f7e2f535468bb75a3326/diff",
                "MergedDir": "/var/lib/docker/overlay2/303314b205ee0cbde8ea315b05b62c6bdca429a495a0a042e3d42f283b7a1ca1/merged",
                "UpperDir": "/var/lib/docker/overlay2/303314b205ee0cbde8ea315b05b62c6bdca429a495a0a042e3d42f283b7a1ca1/diff",
                "WorkDir": "/var/lib/docker/overlay2/303314b205ee0cbde8ea315b05b62c6bdca429a495a0a042e3d42f283b7a1ca1/work"
            },
            "Name": "overlay2"
        },
        "RootFS": {
            "Type": "layers",
            "Layers": [
                "sha256:ce30112909569cead47eac188789d0cf95924b166405aa4b71fb500d6e4ae08d",
                "sha256:8eeb4a14bcb4379021c215017c94800a848a8203a8ce76aa1bd211d4c995f792",
                "sha256:a37e74863e723df4ddd599ef1b7d9a68e2301794a8c37c2370f8c2c8993ef72c",
                "sha256:095624243293a7dfdb582f8471d6e2d9d7772dd621bc57906b034c59f388ebac",
                "sha256:202570302d0b6789f578b44e066de991b1c1d80d3a35ccdc06d32910c21d31e1"
            ]
        },
        "Metadata": {
            "LastTagTime": "2020-08-12T23:24:47.409391947+02:00"
        }
    }
]
```

What we see is a whole bunch of shit, that looks daunting but is in reality quite easy to comprehend:
The first few lines contain general information about the image like tags, when it was created, comments and a global id. Later we find some additional info like author, OS, architecture and size.

But now comes the more interesting part, look at the Config and ContainerConfig fields, they almost look identical but i have significant differences:
ContainerConfig contains the data about the container that was used to create this image and Config contains data about containers that will use this image (if not overwritten otherwise).

The next ominous part is the Graph Driver in order to build the image, this has to do with the storage driver one is using in this case it was overlay2, more on this later.

What are these RootFS and Layers thingie, thats left now? This is the content of our image all the files that are inside our FileSystem. And our filesystem uses layers on top of each other to build the final representation of the filesystem and this is also the reason why we cant the image size even when deleting stuff.

#### Union filesystems (overlay2)

Welcome to the world of union file systems, so how do they look like? Its almost like git you have different kind of layers (commits) and you only store changes. Just on a file basis and not line basis. Here how it looks like:

<div className="Image__Small">
  <img
    src="./images/overlay_constructs.jpg"
    title="OverlayFS"
    alt="Alt text"
  />
</div>

As you can see the merged layer is what is visible by the container, it always accesses the file version of the topmost layer, in which it is available and writes to the upper most layer, until this layer gets "committed" and a new layer gets created. In case of images they are just a bunch of layers, ontop of each other, and this now also explains now why even if we delete files they wont decrease the image size, as the files are still existent in a lower layer.

There exist multiple implementations for such a union file system and the one currently used by Docker by default is overlay2, but depending on use cases, hardware and version you might choose a different one.

A image consists out of multiple image layers on top of each other and a running container adds the container layer which stores all changes in the running container.

### How docker builds images

So how does docker actually build images, as we previosuly have seen when we inspected a image, there is data stored about the container that was used to create this image. And thats hinting us already the right solution: For every step in our Dockerfile Docker creates a new container executes the command and saves the new container as a image, now it executes the next step using the newly created image (rinse and repeat). But not every line in the Dockerfile creates necessarily a new layer, something like `EXPOSE 8000` will only change the image metadata and wont add another layer.

### Consequences out of this process

Now that we understand the building process, how does it help us? What do we learn from it?

#### Choosing the right base image

So what happens if we choose a image that has everything we need inside but more ontop (maybe like `ubuntu:latest`). This will always result in a larger image and there is no way around it, so the best way to keep your images small is by starting out with a image only containing the stuff you really need and add the missing stuff on top. Many images provide slimmer versions only containing runtime dependencies, instead of also containing all development tools for example. If no fitting image exists you can also try creating your own base image, which fits your needs.

Also in regards of security this is important, as we advise to check for security vulnerabilities on the base image you might use (Snyk can help here, also check out their open source security report).

Tip #1: Be specific, never use a tag like `latest` for production images, instead use the most specific it makes sense, maybe something like `bionic` or `12-alpine`. This ensures consistent builds and no unintended changes.

Tip #2: If you need a development/debug image, just base it off the production image and add the dependencies on top, this is how you can keep your images small, but have an easy way to run development modes and have tools accessible.

#### Doing cleanups in the same step

Lets assume we download a bunch of images and later delete some of them that we dont need, this could look somehow like this:

```Dockerfile
FROM ubuntu:latest

COPY . .

RUN ./download_images.sh
RUN ./delete_unnecessary_images.sh
```

At first glance this might look okay, but as we have learned due to how images are built everything is stored in layers, in this case a layer would be created after we executed `./download_images.sh`, so everything we do after that will just increase the size, but there is a way to get the needed result, which looks like this:

```Dockerfile
FROM ubuntu:latest

COPY . .

RUN ./download_images.sh && ./delete_unnecessary_images.sh
```

Now we do both at the same step and the layer hasnt been comitted (created) yet and we will actually reduce the size of the image. Using this exact same way, you can also introduce an additional processing step in between, just concat the statements using `&&`

One more practical example might be to delete apt lists after calling update and installing the package.

So should i just do this with everything? Certainly not, because then you run into the issue that you cant cache anything, either during build or when downloading and also the docker file becomes unreadable.

#### Multi stage builds

But how am i able to keep the image size low and on the same time take full advantage of caching. The magic ingredient is called Multi-Stage-Builds and are quite new in docker, lets take a look at a node example:

```Dockerfile
# BUILDER
FROM node:alpine as builder

WORKDIR /app

COPY . .

RUN yarn install --frozen-lockfile
RUN yarn build


# ACTUAL IMAGE
FROM node:alpine

WORKDIR /app

COPY . .
RUN yarn install --prod --frozen-lockfile
COPY --from=builder /app/dist /app/dist

CMD ["node", "/app/dist/index.js"]
```

Looks nice but what does it do?

The first line looks different this time `FROM node:alpine as builder`. In reality means that we that we just start off from a `node:alpine` image and declare this container/image name to builder for easier later reference.

And now we just do everything as usual after we built the app, we now declare again `FROM node:alpine` and we start our "real" image we want to build this time we just install the production dependencies and now copy the already built app from the builder image/container inside our image, this means in our final image, we dont include any dev depedencies or other unnecessary files, only exactly what we need.

Tip: We already talked about choosing the right base image, utilizing multi stage builds you can for example choose a more bloated image for building with all dev dependencies included and build your application, but your final image can use a much more smaller image, copy the built application from your builder and only install few dependencies if needed (Never choose an image with unneeded stuff, to ensure minimal image size)

But wait the image isnt perfect, everytime we change something in our app it needs to download all dependencies again and it takes forever. So how can we solve this?

### Utilizing cache heavily

To understand how we can improved build caching (and download), we need first to understand how the docker cache works. Caching works in general like the following, as soon as a layers cache is invalidated all layers following are invalidated as well a `RUN` statement is always considered to be cached. In case of `COPY` a checksum of the files gets generated and compared to the cached one.

Knowing this how can we improve our previous image? Ideally we want only to redownload our dependencies if something has changed, and only redo the build. Based on this we can come up with something like this:

```Dockerfile
# BUILDER
FROM node:alpine as builder

WORKDIR /app

COPY package.json yarn.lock .
RUN yarn install --frozen-lockfile
COPY src .
RUN yarn build


# ACTUAL IMAGE
FROM node:alpine

WORKDIR /app

COPY package.json yarn.lock .
RUN yarn install --prod --frozen-lockfile
COPY --from=builder /app/dist /app/dist

CMD ["node", "/app/dist/index.js"]
```

So what is the difference? Instead of copying our whole app we indeed just copy the `package.json` and the `yarn.lock`, this means this layers cache only gets invalidated if one of the two changes, which often times only happens when dependencies change (and some other minor cases). Now we install dependencies and only later we copy our `src` directory. That means in case we change something inside the `src`, our dependencies stay cached and we only redo the build operation. Nice.

Side Note: You can have as many "builders" as you want so maybe you want to do some image resizing, you can do it in another container, and try to achieve a better cache usage.

Tip: Try to order the steps inside your Dockerfile from changes never to changes everytime, also for their processing parts, as this enables faster builds and for the cache to hit more often.

### Preventing token leakage

At some point you might run into a situation where you need to access for example private packages during build time. But how could you do this? One common approach using build arguments could look like this

```Dockerfile
FROM ubuntu:latest

ARG PRIVATE_TOKEN

COPY ./download_private_stuff.sh .

RUN ./download_private_stuff.sh $PRIVATE_TOKEN
```

At first glance this might look okay, but indeed it is not, but why? Lets build the image first:

```
> docker build . -f Leakage.Dockerfile -t leakage:latest --build-arg PRIVATE_TOKEN=123123

Sending build context to Docker daemon  153.1MB
Step 1/4 : FROM ubuntu:latest
 ---> 1e4467b07108
Step 2/4 : ARG PRIVATE_TOKEN
 ---> Running in 05c3cb15d023
Removing intermediate container 05c3cb15d023
 ---> 327b3feb9a8c
Step 3/4 : COPY ./download_private_stuff.sh .
 ---> 065cee25dab2
Step 4/4 : RUN ./download_private_stuff.sh $PRIVATE_TOKEN
 ---> Running in 1e03b4a4b68d
Removing intermediate container 1e03b4a4b68d
 ---> be92167e19d0
Successfully built be92167e19d0
Successfully tagged leakage:latest

> docker inspect leakage:latest

[
    {
        "Id": "sha256:be92167e19d095935eb45ac62d06e5079ad7aae961051446ba77a0f05909b55f",
        "RepoTags": [
            "leakage:latest"
        ],
        "RepoDigests": [],
        "Parent": "sha256:065cee25dab27b3baa4a70e943c10e91ce9f58562f83dbd391dbb52894eba260",
        "Comment": "",
        "Created": "2020-08-14T07:25:42.45657664Z",
        "Container": "1e03b4a4b68d8d8ea52575b65f514be06aeea003fb36bb2f9f6b42fc8c238dfe",
        "ContainerConfig": {
            "Hostname": "",
            "Domainname": "",
            "User": "",
            "AttachStdin": false,
            "AttachStdout": false,
            "AttachStderr": false,
            "Tty": false,
            "OpenStdin": false,
            "StdinOnce": false,
            "Env": [
                "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
            ],
            "Cmd": [
                "|1",
                "PRIVATE_TOKEN=123123",
                "/bin/sh",
                "-c",
                "./download_private_stuff.sh $PRIVATE_TOKEN"
            ],
            "Image": "sha256:065cee25dab27b3baa4a70e943c10e91ce9f58562f83dbd391dbb52894eba260",
            "Volumes": null,
            "WorkingDir": "",
            "Entrypoint": null,
            "OnBuild": null,
            "Labels": null
        },
        "DockerVersion": "19.03.12-ce",
        "Author": "",
        "Config": {
            "Hostname": "",
            "Domainname": "",
            "User": "",
            "AttachStdin": false,
            "AttachStdout": false,
            "AttachStderr": false,
            "Tty": false,
            "OpenStdin": false,
            "StdinOnce": false,
            "Env": [
                "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
            ],
            "Cmd": [
                "/bin/bash"
            ],
            "ArgsEscaped": true,
            "Image": "sha256:065cee25dab27b3baa4a70e943c10e91ce9f58562f83dbd391dbb52894eba260",
            "Volumes": null,
            "WorkingDir": "",
            "Entrypoint": null,
            "OnBuild": null,
            "Labels": null
        },
        "Architecture": "amd64",
        "Os": "linux",
        "Size": 73859057,
        "VirtualSize": 73859057,
        "GraphDriver": {
            "Data": {
                "LowerDir": "/var/lib/docker/overlay2/3224bb80b128bc5ae942f28c2b24c119a8b3933d63ae6e6e8b9b2ef664632964/diff:/var/lib/docker/overlay2/368b18633aa24059c68fdd9e7e71f829be9dcef97155f47f226bdddd000d19d4/diff:/var/lib/docker/overlay2/4186366c68fe0a9a2cec34744a5c6eda300e2fab8a1e8184a1f367cce9a3fa92/diff:/var/lib/docker/overlay2/70b1f1770d0e5dbc64e9d952f53006a5e6399c3a1bb1f7e2f535468bb75a3326/diff",
                "MergedDir": "/var/lib/docker/overlay2/deb0b053bb5e6988dce57a9c33b90543f3c58900da6abb09400cb5b35d641c9f/merged",
                "UpperDir": "/var/lib/docker/overlay2/deb0b053bb5e6988dce57a9c33b90543f3c58900da6abb09400cb5b35d641c9f/diff",
                "WorkDir": "/var/lib/docker/overlay2/deb0b053bb5e6988dce57a9c33b90543f3c58900da6abb09400cb5b35d641c9f/work"
            },
            "Name": "overlay2"
        },
        "RootFS": {
            "Type": "layers",
            "Layers": [
                "sha256:ce30112909569cead47eac188789d0cf95924b166405aa4b71fb500d6e4ae08d",
                "sha256:8eeb4a14bcb4379021c215017c94800a848a8203a8ce76aa1bd211d4c995f792",
                "sha256:a37e74863e723df4ddd599ef1b7d9a68e2301794a8c37c2370f8c2c8993ef72c",
                "sha256:095624243293a7dfdb582f8471d6e2d9d7772dd621bc57906b034c59f388ebac",
                "sha256:feae1a6a1806ac51f0edd1b510499f886f75ed40b0fe3bf4d5e5ec80190d9bf8"
            ]
        },
        "Metadata": {
            "LastTagTime": "2020-08-14T09:25:43.111692616+02:00"
        }
    }
]
```

To check the critical part lets look at the container config, the container that was used to create this image, inside the `CMD` we can refind that at every `RUN` our build argument gets inserted in front of the statement. This allows possible attackers to get our token as soon as they get one docker image and should be prevented at all costs.

But how to do it right? If this is not the right way what is?

There are actually multiple one of them is again using a multi stage build, due to the nature of it, as the past of the builder is not stored you can download inside a builder safely and copy the results into your final container/image, like this:

```Dockerfile
FROM ubuntu:latest as builder

WORKDIR /

ARG PRIVATE_TOKEN

COPY ./download_private_stuff.sh .

RUN ./download_private_stuff.sh $PRIVATE_TOKEN

FROM ubuntu:latest

COPY --from=builder /private_stuff .
```

Now our secret is kept secure :)

Tip: Use `.dockerignore` files to ensure unwanted files are never copied inside the container (may be happening using a recursive `COPY`, also this will increase your build performance as the context will be smaller)

### Buildkit

#### Better secret management

But beware there is an even better solution, at least soon, called Buildkit and the experimental features that come with it. Most likely you use the standard docker builder when you are building an image, Buildkit is the next generation image builder by Docker that features better performance, better cache evaluation and complete freedom of choice of frontends (for example a Dockerfile, yeah you can write your own frontend if you like).

Tip: Buildkit is preinstalled with every docker version greater than 18.03 just set a ENV to `DOCKER_BUILDKIT=1` to enable it. But beware its still experimental.

So what does buildkits experimental features bring that will help us managing our secrets?

Using buildkit you can mount directories or Docker secrets (or even ssh keys) inside the container during buildtime. Lets look at an example:

```Dockerfile
# syntax = docker/dockerfile:1.0-experimental
FROM ubuntu:latest

# shows secret from default secret location
RUN --mount=type=secret,id=mysecret cat /run/secrets/mysecret

# shows secret from custom secret location
RUN --mount=type=secret,id=mysecret,target=/foobar cat /foobar
```

One thing you might have noticed is the first line `# syntax = docker/dockerfile:1.0-experimental` which we need to specify that buildkit should use the experimental Dockerfile frontend which enables these features.

#### Speeding up builds even more, utilizing more caching

So how can we utilize these new experimental features for even faster builds? Depending on what you build there might be multiple things but here are a few examples:

1. Cache the dependencies directory (for example yarn keeps a global cache), so even when you change the dependencies it doesnt need to refetch everything but just whats needed and the rest is loaded from cache
2. If your build process allows for incremental builds, you can store your build artifacts so next time the compiler can use these for a faster build

One example might also be caching apt like this:

```Dockerfile
# syntax = docker/dockerfile:experimental
FROM ubuntu

RUN rm -f /etc/apt/apt.conf.d/docker-clean; echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
RUN --mount=type=cache,target=/var/cache/apt --mount=type=cache,target=/var/lib/apt \
  apt update && apt-get --no-install-recommends install -y gcc
```

### Why do you even need all this optimization?

These optimizations result in multiple, desirable positive results like:

- Faster development and builds, also in the CI/CD by utilizing caching heavily
- Cost savings (lower image sizes)
- More secure images, preventing token leakages and less known vulnerabilities
- Faster startup time of containers (beneficial when running on k8s or similar orchestrators)

### Other tips

#### Linting Docker Images

Use something like [hadolint](https://github.com/hadolint/hadolint) or similar to lint your docker image as well as shell commands. This can help writing better Dockerfiles more easily.

#### Use the least privileged user

Often times you see images running a process as root, which is not really secure, even inside containers, so instead of running your application as root, try to create a user and give him necessary privileges. Images like `node` come for example with a predefined user node, which you can easily use adding this inside the Dockerfile `USER node` after doing all the build steps.

#### COPY instead of ADD

If you are sure you will only copy from your local filesystem try to use `COPY` instead of `ADD`, as it is more explicit (explicit > implicit).

#### One job per image/container

It is possible to run multiple things inside a container, but generally speaking you should avoid it. You want to dynamically deploy services and singular components and one of the results is a container only doing 1 thing (like UNIX systems).

#### Implement a HEALTHCHECK

To ensure your services are up and functional all the time, add a `HEALTHCHECK` inside your image that can report a container as being unhealthy in case, something is up, so the container is able to get restarted automatically.

#### LABEL images appropiately

Docker offers to label images with metadata such like maintainers, securitytxt and other stuff. Do this to ensure the info is easily accessible (especially when the image is public).

#### Everything is an API

The docker engine offers an API, to interact with containers, images, etc. and it literally contains everything as even the CLI uses this API. So if you ever need to automate something look at the API :)

#### Be aware of PID 1

When you use something like `CMD ./entrypoint.sh` this process will be spawned and will get the PID 1 which means all abandoned processes will move to it (This is a unix system trait). Normally this process is something like systemd which takes care of killing of abandoned processes, which get assigned to it. But why is this important, this means the process you need to spawn needs to take proper care of reacting to `SIGnals` and gracefully terminate child processes. For example bash scripts wont do this properly and you should use something like tini to be able to gracefully shut down (Or register signal handlers inside your application).

## Runtime Best Practices

### Storing application data inside volumes (vs bind mounts)

In case your process uses the filesystem you need to take care of where to write your files to. Two possible solutions are either volumes or bind mounts, but which one to choose?

In general any application data thats written and only accessed by the application should be stored inside a volume (to ensure this you can use `VOLUME /path/to/dir` inside your image), this ensures better performance compared to writing it to a layer and enables plugging volumes dynamically.

For development purposes you can also use bind mounts (to be able to access the data from the host), to increase performance check out delegated, cached and consistent consistency levels to improve performance for bind mounts.

## Docker Checklist

Coming Soon (TM)
