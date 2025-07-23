import { Ok, Error } from "./gleam.mjs";
import { Log, UserManager } from 'oidc-client-ts';

Log.setLogger(console);
Log.setLevel(Log.INFO);

const url = window.location.origin

export async function signin(authority, client_id) {
    let um = new UserManager({
        authority: authority,
        client_id: client_id,
        redirect_uri: url + "/oidc/callback",
        scope: "openid profile email roles",
    })
    
    try {
        let user = await um.signinPopup()
        console.log(user)
        return new Ok(user.access_token)
    } catch(err) {
        console.error(err)
        return new Error(undefined)
    }
}

export async function callback(authority, client_id) {
    let um = new UserManager({
        authority: authority,
        client_id: client_id,
        redirect_uri: url + "/oidc/callback",
        scope: "openid profile email roles",
    })
    
    try {
        let user = await um.signinCallback()
        console.log(user)
        return new Ok(undefined)
    } catch(err) {
        console.error(err)
        return new Error(undefined)
    }
}
