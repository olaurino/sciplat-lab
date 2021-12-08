ifeq ($(tag),)
    $(error tag must be set)
endif

ifeq ($(image),)
    image = docker.io/lsstsqre/sciplat-lab
    # Some day this might be a ghcr.io default
endif

# There are no targets in the classic sense, and there is a strict linear
#  dependency from building the dockerfile to the image to pushing it.

.PHONY: clean dockerfile image push all

all: push

# push assumes that the building user already has docker credentials
#  to push to whatever the target repository (specified in $(image)) may be.
push: image
	./build/push_image $(tag) $(image) $(supplementary)

image: dockerfile
	./build/build_image $(tag) $(image) $(supplementary)

dockerfile: clean
	./build/make_dockerfile $(tag) $(image) $(supplementary)

clean:
	rm -f Dockerfile
