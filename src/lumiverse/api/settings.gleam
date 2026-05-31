import gleam/dynamic/decode
import gleam/json
import lumiverse/api/fetch

pub type SmtpConfig {
  SmtpConfig(
    sender_address: String,
    sender_display_name: String,
    user_name: String,
    password: String,
    host: String,
    port: Int,
    enable_ssl: Bool,
    size_limit: Int,
    customized_templates: Bool,
  )
}

pub type OIDCConfig {
  OIDCConfig(
    enabled: Bool,
    auto_login: Bool,
    disable_password_auth: Bool,
    provider_name: String,
    authority: String,
    client_id: String,
    secret: String,
    provision_accounts: Bool,
    require_verified_email: Bool,
    sync_user_settings: Bool,
    roles_prefix: String,
    roles_claim: String,
    custom_scopes: List(String),
    default_roles: List(String),
    default_libraries: List(Int),
    default_age_restriction: Int,
    default_include_unknowns: Bool,
  )
}

pub type ServerSettings {
  ServerSettings(
    cache_directory: String,
    task_scan: String,
    task_backup: String,
    task_cleanup: String,
    task_cbl_sync: String,
    logging_level: String,
    port: Int,
    ip_addresses: String,
    allow_stat_collection: Bool,
    enable_opds: Bool,
    base_url: String,
    bookmarks_directory: String,
    install_version: String,
    install_id: String,
    encode_media_as: Int,
    total_backups: Int,
    enable_folder_watching: Bool,
    total_logs: Int,
    host_name: String,
    cache_size: Int,
    on_deck_progress_days: Int,
    on_deck_update_days: Int,
    cover_image_size: Int,
    pdf_render_resolution: Int,
    smtp_config: SmtpConfig,
    oidc_config: OIDCConfig,
    first_install_date: String,
    first_install_version: String,
    stats_api_hits: Int,
  )
}

fn smtp_config_decoder() {
  use sender_address <- decode.field("senderAddress", decode.string)
  use sender_display_name <- decode.field("senderDisplayName", decode.string)
  use user_name <- decode.field("userName", decode.string)
  use password <- decode.field("password", decode.string)
  use host <- decode.field("host", decode.string)
  use port <- decode.field("port", decode.int)
  use enable_ssl <- decode.field("enableSsl", decode.bool)
  use size_limit <- decode.field("sizeLimit", decode.int)
  use customized_templates <- decode.field("customizedTemplates", decode.bool)
  decode.success(SmtpConfig(
    sender_address:,
    sender_display_name:,
    user_name:,
    password:,
    host:,
    port:,
    enable_ssl:,
    size_limit:,
    customized_templates:,
  ))
}

fn nullable_string() {
  decode.one_of(decode.string, [decode.success("")])
}

fn nullable_list(inner) {
  decode.one_of(decode.list(inner), [decode.success([])])
}

fn oidc_config_decoder() {
  use enabled <- decode.field("enabled", decode.bool)
  use auto_login <- decode.field("autoLogin", decode.bool)
  use disable_password_auth <- decode.field(
    "disablePasswordAuthentication",
    decode.bool,
  )
  use provider_name <- decode.field("providerName", nullable_string())
  use authority <- decode.field("authority", nullable_string())
  use client_id <- decode.field("clientId", nullable_string())
  use secret <- decode.field("secret", nullable_string())
  use provision_accounts <- decode.field("provisionAccounts", decode.bool)
  use require_verified_email <- decode.field("requireVerifiedEmail", decode.bool)
  use sync_user_settings <- decode.field("syncUserSettings", decode.bool)
  use roles_prefix <- decode.field("rolesPrefix", nullable_string())
  use roles_claim <- decode.field("rolesClaim", nullable_string())
  use custom_scopes <- decode.field("customScopes", nullable_list(decode.string))
  use default_roles <- decode.field("defaultRoles", nullable_list(decode.string))
  use default_libraries <- decode.field(
    "defaultLibraries",
    nullable_list(decode.int),
  )
  use default_age_restriction <- decode.field(
    "defaultAgeRestriction",
    decode.int,
  )
  use default_include_unknowns <- decode.field(
    "defaultIncludeUnknowns",
    decode.bool,
  )
  decode.success(OIDCConfig(
    enabled:,
    auto_login:,
    disable_password_auth:,
    provider_name:,
    authority:,
    client_id:,
    secret:,
    provision_accounts:,
    require_verified_email:,
    sync_user_settings:,
    roles_prefix:,
    roles_claim:,
    custom_scopes:,
    default_roles:,
    default_libraries:,
    default_age_restriction:,
    default_include_unknowns:,
  ))
}

fn server_settings_decoder() {
  use cache_directory <- decode.field("cacheDirectory", decode.string)
  use task_scan <- decode.field("taskScan", decode.string)
  use task_backup <- decode.field("taskBackup", decode.string)
  use task_cleanup <- decode.field("taskCleanup", decode.string)
  use task_cbl_sync <- decode.field("taskCblSync", decode.string)
  use logging_level <- decode.field("loggingLevel", decode.string)
  use port <- decode.field("port", decode.int)
  use ip_addresses <- decode.field("ipAddresses", nullable_string())
  use allow_stat_collection <- decode.field("allowStatCollection", decode.bool)
  use enable_opds <- decode.field("enableOpds", decode.bool)
  use base_url <- decode.field("baseUrl", decode.string)
  use bookmarks_directory <- decode.field("bookmarksDirectory", decode.string)
  use install_version <- decode.field("installVersion", decode.string)
  use install_id <- decode.field("installId", decode.string)
  use encode_media_as <- decode.field("encodeMediaAs", decode.int)
  use total_backups <- decode.field("totalBackups", decode.int)
  use enable_folder_watching <- decode.field("enableFolderWatching", decode.bool)
  use total_logs <- decode.field("totalLogs", decode.int)
  use host_name <- decode.field("hostName", nullable_string())
  use cache_size <- decode.field("cacheSize", decode.int)
  use on_deck_progress_days <- decode.field("onDeckProgressDays", decode.int)
  use on_deck_update_days <- decode.field("onDeckUpdateDays", decode.int)
  use cover_image_size <- decode.field("coverImageSize", decode.int)
  use pdf_render_resolution <- decode.field("pdfRenderResolution", decode.int)
  use smtp_config <- decode.field("smtpConfig", smtp_config_decoder())
  use oidc_config <- decode.field("oidcConfig", oidc_config_decoder())
  use first_install_date <- decode.field("firstInstallDate", nullable_string())
  use first_install_version <- decode.field(
    "firstInstallVersion",
    nullable_string(),
  )
  use stats_api_hits <- decode.field("statsApiHits", decode.int)
  decode.success(ServerSettings(
    cache_directory:,
    task_scan:,
    task_backup:,
    task_cleanup:,
    task_cbl_sync:,
    logging_level:,
    port:,
    ip_addresses:,
    allow_stat_collection:,
    enable_opds:,
    base_url:,
    bookmarks_directory:,
    install_version:,
    install_id:,
    encode_media_as:,
    total_backups:,
    enable_folder_watching:,
    total_logs:,
    host_name:,
    cache_size:,
    on_deck_progress_days:,
    on_deck_update_days:,
    cover_image_size:,
    pdf_render_resolution:,
    smtp_config:,
    oidc_config:,
    first_install_date:,
    first_install_version:,
    stats_api_hits:,
  ))
}

fn encode_smtp_config(c: SmtpConfig) -> json.Json {
  json.object([
    #("senderAddress", json.string(c.sender_address)),
    #("senderDisplayName", json.string(c.sender_display_name)),
    #("userName", json.string(c.user_name)),
    #("password", json.string(c.password)),
    #("host", json.string(c.host)),
    #("port", json.int(c.port)),
    #("enableSsl", json.bool(c.enable_ssl)),
    #("sizeLimit", json.int(c.size_limit)),
    #("customizedTemplates", json.bool(c.customized_templates)),
  ])
}

fn encode_oidc_config(c: OIDCConfig) -> json.Json {
  json.object([
    #("enabled", json.bool(c.enabled)),
    #("autoLogin", json.bool(c.auto_login)),
    #("disablePasswordAuthentication", json.bool(c.disable_password_auth)),
    #("providerName", json.string(c.provider_name)),
    #("authority", json.string(c.authority)),
    #("clientId", json.string(c.client_id)),
    #("secret", json.string(c.secret)),
    #("provisionAccounts", json.bool(c.provision_accounts)),
    #("requireVerifiedEmail", json.bool(c.require_verified_email)),
    #("syncUserSettings", json.bool(c.sync_user_settings)),
    #("rolesPrefix", json.string(c.roles_prefix)),
    #("rolesClaim", json.string(c.roles_claim)),
    #("customScopes", json.array(c.custom_scopes, json.string)),
    #("defaultRoles", json.array(c.default_roles, json.string)),
    #("defaultLibraries", json.array(c.default_libraries, json.int)),
    #("defaultAgeRestriction", json.int(c.default_age_restriction)),
    #("defaultIncludeUnknowns", json.bool(c.default_include_unknowns)),
  ])
}

fn encode_server_settings(s: ServerSettings) -> json.Json {
  json.object([
    #("cacheDirectory", json.string(s.cache_directory)),
    #("taskScan", json.string(s.task_scan)),
    #("taskBackup", json.string(s.task_backup)),
    #("taskCleanup", json.string(s.task_cleanup)),
    #("taskCblSync", json.string(s.task_cbl_sync)),
    #("loggingLevel", json.string(s.logging_level)),
    #("port", json.int(s.port)),
    #("ipAddresses", json.string(s.ip_addresses)),
    #("allowStatCollection", json.bool(s.allow_stat_collection)),
    #("enableOpds", json.bool(s.enable_opds)),
    #("baseUrl", json.string(s.base_url)),
    #("bookmarksDirectory", json.string(s.bookmarks_directory)),
    #("installVersion", json.string(s.install_version)),
    #("installId", json.string(s.install_id)),
    #("encodeMediaAs", json.int(s.encode_media_as)),
    #("totalBackups", json.int(s.total_backups)),
    #("enableFolderWatching", json.bool(s.enable_folder_watching)),
    #("totalLogs", json.int(s.total_logs)),
    #("hostName", json.string(s.host_name)),
    #("cacheSize", json.int(s.cache_size)),
    #("onDeckProgressDays", json.int(s.on_deck_progress_days)),
    #("onDeckUpdateDays", json.int(s.on_deck_update_days)),
    #("coverImageSize", json.int(s.cover_image_size)),
    #("pdfRenderResolution", json.int(s.pdf_render_resolution)),
    #("smtpConfig", encode_smtp_config(s.smtp_config)),
    #("oidcConfig", encode_oidc_config(s.oidc_config)),
    #("firstInstallDate", json.string(s.first_install_date)),
    #("firstInstallVersion", json.string(s.first_install_version)),
    #("statsApiHits", json.int(s.stats_api_hits)),
  ])
}

pub fn get(resp) {
  fetch.get("/api/settings", server_settings_decoder(), resp)
}

pub fn save(s: ServerSettings, resp) {
  fetch.post_empty("/api/settings", encode_server_settings(s), resp)
}
