export function get(key) {
    if(!window.config) {return ''}
    return window.config[key] || ''
}
