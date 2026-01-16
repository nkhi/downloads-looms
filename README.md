# download looms for freeeee
no business plan? no problem. download all your looms and put them somewhere else

all credit to this helpful guide and it's creator: https://gist.github.com/devinschumacher/b7be00df9d9809d0ea55663d88dc9d3c

---

0. clone or download repo
1. add your loom urls to the /loomurls.txt
```
https://www.loom.com/share/<videoId>
https://www.loom.com/share/<videoId>
...
```

2. update perms and run script

```
chmod +x download_looms.sh && ./download_looms.sh
```
```
# download only the first video
./download_looms.sh --trial-run 

# extra logging
./download_looms.sh --verbose
```

3. check root for mp4 output videos.

🌈🌈🌈🌈🌈🌈🌈🌈
