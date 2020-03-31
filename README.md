# meta-authority
Custom authority for allowing META to govern META.

Intentionally simple. Once set as the META token's authority, if the META token's `owner` field is subsequently set to
zero, the following properties obtain:
* any user may call META's `burn` function
* only authorized users (according to the MetaAuthority's `ward`s) can call META's `mint()` function
* only the `root` user set in the authority can call other `auth`-protected functions of the META contract
* only the `root` user can modify the MetaAuthority's `ward`s or change the `root`

Though this contract could be used in different ways, it was designed in the context of an overall design for control
of the META token via META governance as illustrated below.

```
<~~~ : points to source's authority
<=== : points to source's root or owner

-------    -------    ------------    --------------    -----
|Chief|<~~~|Pause|<===|PauseProxy|<===|MetaAuthority|<~~~|META|===>0
-------    -------    ------------    --------------    -----
```

Such a structure allows governance proposals voted in on the Chief to make arbtirary changes to the META token
and its permissions subject to a delay. (See DappHub contracts
[DSChief](https://github.com/dapphub/ds-chief) and [DSPause](https://github.com/dapphub/ds-pause)
for implementations of the voting contract and the delay contract, respectively.)

Note that the MetaAuthority allows for upgrading of the META token's `authority` or `owner` by the `root`.
