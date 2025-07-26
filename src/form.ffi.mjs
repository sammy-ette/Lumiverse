import { Ok, Error } from "./gleam.mjs";

export async function submit(elementID, headers) {
    let elem = document.querySelector("#" + elementID)
    console.log(elem)
    let formdata = new FormData(elem)

    try {
        console.log("element action: ", elem.action)
        let resp = await fetch(elem.action, {
            method: elem.method,
            body: formdata,
            headers: headers
        })

        if (resp.ok) {
            return new Ok(undefined)
        } else {
            return new Error(undefined)
        }
    } catch(err) {
        console.error(err)
        return new Error(undefined)
    }
}
