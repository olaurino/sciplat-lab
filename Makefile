# We need three pieces of information to build the container:
#  tag is the tag on the input DM Stack container.  It is mandatory.
#  image is the Docker repository image we're pushing to; we can use the
#   default if we don't specify it, which goes to Docker Hub.  image
#   may be a comma-separated list of target repositories.
#  supplementary is an additional tag, which forces the build to an "exp_"
#   (that is, experimental) tag and adds "_" plus the supplement at the end.

# Therefore: the typical use of the Makefile would look like:
#   make tag=w_2021_50

# To push to a different repository:
#   make tag=w_2021_50 image=ghcr.io/lsst-sqre/sciplat-lab

# To use a different input image:
#   make tag=w_2021_49_c0023.008 \
#    input=ts-dockerhub.lsst.org/lsstts/sal-sciplat: \
#    image=ts-dockerhub.lsst.org/lsstts/sal-sciplat-lab

# To tag as experimental "foo" (-> exp_w_2021_50_foo):
#   make tag=w_2021_50 supplementary=foo

# There are four targets: clean, dockerfile, image, and push.  The default
#  is "push", and the four are always done in strict linear order.  "clean"
#  just removes the generated Dockerfile.  "dockerfile" generates the
#  Dockerfile from the template, but does not build an image or push it.
#  "image" builds the image with Docker but does not push it to a repository.
#  "push" (aka "all") also pushes the built image.  It assumes that the
#  building user already has appropriate push credentials set.

ifeq ($(tag),)
    $(error tag must be set)
endif

ifeq ($(image),)
    image = docker.io/lsstsqre/sciplat-lab
    # Some day this might be a ghcr.io default
endif

ifeq ($(input),)
    input = docker.io/lsstsqre/centos:7-stack-lsst_distrib-
    # You need to include the colon here, and the input tag has to
    # end with $(tag)
endif

# Some day we might use a different build tool.  If you have a new enough
#  docker, you probably want to set DOCKER_BUILDKIT in your environment.
DOCKER := docker

# Force to simply-expanded variables, for when we add the supplementary tag.
tag := $(tag)
image := $(image)
#  version is the tag on the output JupyterLab container.  Releases
#   change the first letter of the tag from "v" to "r", and if a supplementary
#   version is added, the tag will be marked as "exp_" with the supplement
#   added at the end after an underscore.
version := $(tag)
version := $(version:v%=r%)

release_branch := prod
branch := $(shell git rev-parse --abbrev-ref HEAD)

# if we are not on the release branch, then force supplementary to be set
ifneq ($(branch),$(release_branch))
    ifeq ($(supplementary),)
        supplementary := $(shell echo $(branch) | tr -c -d \[A-z\]\[0-9\])
    endif
endif
ifneq ($(supplementary),)
    version := exp_$(version)_$(supplementary)
endif

# We don't have an arm64 build of the DM stack yet, so if you happen to be
#  building on such a machine (e.g. Apple Silicon), cross-build to amd64
#  instead

uname := $(shell uname -p)
ifeq ($(uname),arm)
    platform := --platform amd64
endif

# Experimentals do not get tagged as latest anything.  Dailies, weeklies, and
#  releases get tagged as latest_<category>.  The "latest" tag for the lab
#  container should always point to the latest weekly or release, but not a
#  daily, since we make no guarantees that the daily is fit for purpose.

tag_type = $(shell echo $(version) | cut -c 1)
ifeq ($(tag_type),w)
    ltype := latest_weekly
    latest := latest
else ifeq ($(tag_type),r)
    # if it's got an "rc" in the name, it's a release candidate, and we don't
    #  want to tag it as latest anything either.
    ifeq ($(findstring rc, $(version)),)
       ltype := latest_release
       latest := latest
    endif
else ifeq ($(tag_type),d)
    ltype := latest_daily
endif

# There are no targets in the classic sense, and there is a strict linear
#  dependency from building the dockerfile to the image to pushing it.

# "all" and "build" are just aliases for "push" and "image" respectively.

.PHONY: all push build image dockerfile clean

all: push

# push assumes that the building user already has docker credentials
#  to push to whatever the target repository or repositories (specified in
#  $(image), possibly as a comma-separated list of targets) may be.
push: image
	img=$$(echo $(image) | cut -d ',' -f 1) && \
	more=$$(echo $(image) | cut -d ',' -f 2- | tr ',' ' ') && \
	$(DOCKER) push $${img}:$(version) && \
	for m in $${more}; do \
	    $(DOCKER) tag $${img}:$(version) $${m}:$(version) ; \
	    $(DOCKER) push $${m}:$(version) ; \
	done && \
	if [ -n "$(ltype)" ]; then \
	    $(DOCKER) tag $${img}:$(version) $${img}:$(ltype) ; \
	    $(DOCKER) push $${img}:$(ltype) ; \
	fi && \
	if [ -n "$(latest)" ]; then \
	    $(DOCKER) tag $${img}:$(version) $${img}:$(latest) ; \
	    $(DOCKER) push $${img}:$(latest) ; \
	fi

# I keep getting this wrong, so make it work either way.
build: image

image: dockerfile
	img=$$(echo $(image) | cut -d ',' -f 1) && \
	more=$$(echo $(image) | cut -d ',' -f 2- | tr ',' ' ') && \
	$(DOCKER) build ${platform} --progress=plain -t $${img}:$(version) . && \
	for m in $${more}; do \
	    $(DOCKER) tag $${img}:$(version) $${m}:$(version) ; \
	done

dockerfile: clean
	img=$$(echo $(image) | cut -d ',' -f 1) && \
	sed -e "s|{{IMAGE}}|$${img})|g" \
	    -e "s|{{VERSION}}|$(version)|g" \
	    -e "s|{{INPUT}}|$(input)|g" \
	    -e "s|{{TAG}}|$(tag)|g" \
	    < Dockerfile.template > Dockerfile

clean:
	rm -f Dockerfile
