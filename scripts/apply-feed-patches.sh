#!/bin/sh
# Overlay the patches kept in feed-patches/ onto the feeds/ checkout.
# feed-patches/ mirrors the feeds/ tree (e.g. feed-patches/packages/...).
set -e
[ -d feed-patches ] || exit 0
cp -a feed-patches/. feeds/
