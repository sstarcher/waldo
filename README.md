### Exercise for Waldo Photos

Ruby and mongodb

Prereq:
* Mongodb installed locally
* Ruby

Verification
```
mongo waldo --eval='printjson(db.photos.count())'

mongo waldo --eval="db.photos.find({name: '01a11242-35d0-4865-8f90-5db01a30ed51.e8ae7a45-8b4c-4142-b3d2-0f631d543b20.jpg'})"

or

mongo waldo --eval="db.photos.find({name: /.*35d0.*/})"
```