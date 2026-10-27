// SPDX-License-Identifier: GPL-3.0-only
#include "ExternalAuthService.h"
#include <QDateTime>
#include <QJsonArray>
#include <QJsonDocument>
#include <QNetworkReply>
#include <QUrlQuery>
#include <openssl/evp.h>
#include <openssl/rsa.h>
#ifdef Q_OS_WIN
#include <windows.h>
#include <wincrypt.h>
#endif

namespace DeeraftAuth {
QByteArray protect(const QByteArray& plain)
{
#ifdef Q_OS_WIN
    DATA_BLOB input{DWORD(plain.size()), reinterpret_cast<BYTE*>(const_cast<char*>(plain.constData()))}, output{};
    if (!CryptProtectData(&input, L"DeeraftApp external Minecraft account", nullptr, nullptr, nullptr,
                          CRYPTPROTECT_UI_FORBIDDEN, &output)) return {};
    QByteArray result(reinterpret_cast<char*>(output.pbData), output.cbData);
    LocalFree(output.pbData);
    return result;
#else
    // Never fall back to writing third-party credentials in plain text.
    Q_UNUSED(plain);
    return {};
#endif
}
QByteArray unprotect(const QByteArray& cipher)
{
#ifdef Q_OS_WIN
    DATA_BLOB input{DWORD(cipher.size()), reinterpret_cast<BYTE*>(const_cast<char*>(cipher.constData()))}, output{};
    if (!CryptUnprotectData(&input, nullptr, nullptr, nullptr, nullptr, CRYPTPROTECT_UI_FORBIDDEN, &output)) return {};
    QByteArray result(reinterpret_cast<char*>(output.pbData), output.cbData);
    LocalFree(output.pbData);
    return result;
#else
    Q_UNUSED(cipher);
    return {};
#endif
}
bool secureUrl(const QUrl& url)
{
    return url.isValid() && url.scheme() == "https" && !url.host().isEmpty() && url.userInfo().isEmpty();
}
QUrl apiRoot(QString input)
{
    input = input.trimmed();
    while (input.endsWith('/')) input.chop(1);
    if (input.endsWith("/authserver", Qt::CaseInsensitive)) input.chop(11);
    return QUrl(input);
}
void request(QNetworkAccessManager* network, const QUrl& url, const QJsonObject& body, JsonCallback done,
             bool form, const QString& bearer)
{
    if (!secureUrl(url)) { done({}, QStringLiteral("认证地址必须使用 HTTPS")); return; }
    QNetworkRequest request(url);
    request.setTransferTimeout(30000);
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::SameOriginRedirectPolicy);
    request.setRawHeader("Accept", "application/json");
    if (!bearer.isEmpty()) request.setRawHeader("Authorization", "Bearer " + bearer.toUtf8());
    QNetworkReply* reply;
    if (body.isEmpty()) reply = network->get(request);
    else {
        QByteArray payload;
        if (form) {
            QUrlQuery query;
            for (auto it = body.begin(); it != body.end(); ++it) query.addQueryItem(it.key(), it.value().toString());
            payload = query.query(QUrl::FullyEncoded).toUtf8();
            request.setHeader(QNetworkRequest::ContentTypeHeader, "application/x-www-form-urlencoded");
        } else {
            request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
            payload = QJsonDocument(body).toJson(QJsonDocument::Compact);
        }
        reply = network->post(request, payload);
    }
    QObject::connect(reply, &QNetworkReply::finished, network, [reply, done = std::move(done)] {
        const auto bytes = reply->readAll();
        const auto document = QJsonDocument::fromJson(bytes);
        const auto object = document.object();
        QString error;
        if (reply->error() != QNetworkReply::NoError) {
            error = object.value("errorMessage").toString(object.value("error_description").toString(reply->errorString()));
        } else if (!document.isObject()) error = QStringLiteral("认证服务器返回了无效 JSON");
        else if (object.contains("error")) error = object.value("errorMessage").toString(object.value("error_description").toString(object.value("error").toString()));
        reply->deleteLater();
        done(object, error);
    });
}
void discover(QNetworkAccessManager* network, const QUrl& url, JsonCallback done)
{
    request(network, url, {}, [url, done](QJsonObject meta, QString error) {
        if (!error.isEmpty()) { done({}, error); return; }
        const QUrl issuer(meta.value("issuer").toString());
        if (!secureUrl(issuer) || issuer.authority() != url.authority()) {
            done({}, QStringLiteral("发现文档与签发者地址不匹配")); return;
        }
        for (const auto& field : {"token_endpoint", "device_authorization_endpoint", "jwks_uri", "userinfo_endpoint"}) {
            if (!secureUrl(QUrl(meta.value(field).toString()))) {
                done({}, QStringLiteral("发现文档缺少有效的 HTTPS 端点：") + field); return;
            }
        }
        const auto scopes = meta.value("scopes_supported").toArray();
        for (const auto& scope : {"openid", "Yggdrasil.PlayerProfiles.Select", "Yggdrasil.Server.Join"}) {
            if (!scopes.contains(QString::fromLatin1(scope))) { done({}, QStringLiteral("站点未声明 Yggdrasil Connect 所需权限")); return; }
        }
        done(meta, {});
    });
}
static QByteArray decode(const QString& value) { return QByteArray::fromBase64(value.toLatin1(), QByteArray::Base64UrlEncoding); }
static bool verifySignature(const QByteArray& signedBytes, const QByteArray& signature, const QJsonObject& key)
{
    if (key.value("kty").toString() != "RSA") return false;
    const auto modulus = decode(key.value("n").toString());
    const auto exponent = decode(key.value("e").toString());
    if (modulus.size() < 256 || exponent.isEmpty()) return false;
    RSA* rsa = RSA_new();
    BIGNUM* n = BN_bin2bn(reinterpret_cast<const unsigned char*>(modulus.constData()), modulus.size(), nullptr);
    BIGNUM* e = BN_bin2bn(reinterpret_cast<const unsigned char*>(exponent.constData()), exponent.size(), nullptr);
    if (!rsa || !n || !e || !RSA_set0_key(rsa, n, e, nullptr)) {
        RSA_free(rsa); BN_free(n); BN_free(e); return false;
    }
    EVP_PKEY* publicKey = EVP_PKEY_new();
    if (!publicKey || EVP_PKEY_assign_RSA(publicKey, rsa) != 1) { EVP_PKEY_free(publicKey); RSA_free(rsa); return false; }
    EVP_MD_CTX* context = EVP_MD_CTX_new();
    bool valid = context && EVP_DigestVerifyInit(context, nullptr, EVP_sha256(), nullptr, publicKey) == 1
        && EVP_DigestVerify(context, reinterpret_cast<const unsigned char*>(signature.constData()), signature.size(),
                            reinterpret_cast<const unsigned char*>(signedBytes.constData()), signedBytes.size()) == 1;
    EVP_MD_CTX_free(context); EVP_PKEY_free(publicKey);
    return valid;
}
void verifyConnect(QNetworkAccessManager* network, const QJsonObject& metadata, const QString& clientId,
                   const QJsonObject& tokens, JsonCallback done)
{
    const auto parts = tokens.value("id_token").toString().split('.');
    if (parts.size() != 3 || tokens.value("access_token").toString().isEmpty()) { done({}, QStringLiteral("站点未返回完整的 OpenID 令牌")); return; }
    const auto header = QJsonDocument::fromJson(decode(parts[0])).object();
    const auto claims = QJsonDocument::fromJson(decode(parts[1])).object();
    const auto now = QDateTime::currentSecsSinceEpoch();
    const auto audience = claims.value("aud");
    const bool audienceMatches = audience.toString() == clientId || audience.toArray().contains(clientId);
    if (header.value("alg").toString() != "RS256" || header.value("kid").toString().isEmpty()
        || claims.value("iss") != metadata.value("issuer") || !audienceMatches
        || claims.value("sub").toString().isEmpty() || claims.value("exp").toDouble() <= now
        || !claims.contains("iat") || claims.value("iat").toDouble() > now + 60
        || (claims.contains("nbf") && claims.value("nbf").toDouble() > now + 60)
        || (audience.isArray() && audience.toArray().size() > 1 && claims.value("azp").toString() != clientId)) {
        done({}, QStringLiteral("OpenID 令牌声明校验失败，或使用了不支持的签名算法")); return;
    }
    request(network, QUrl(metadata.value("jwks_uri").toString()), {},
        [network, metadata, tokens, claims, header, parts, done](QJsonObject jwks, QString error) {
        if (!error.isEmpty()) { done({}, error); return; }
        bool valid = false;
        for (const auto& key : jwks.value("keys").toArray()) {
            auto object = key.toObject();
            if (object.value("kid") == header.value("kid") && (!object.contains("use") || object.value("use").toString() == "sig")
                && (!object.contains("alg") || object.value("alg").toString() == "RS256")) {
                valid = verifySignature((parts[0] + '.' + parts[1]).toLatin1(), decode(parts[2]), object);
                if (valid) break;
            }
        }
        if (!valid) { done({}, QStringLiteral("OpenID 令牌签名校验失败")); return; }
        request(network, QUrl(metadata.value("userinfo_endpoint").toString()), {},
            [claims, done](QJsonObject user, QString error) {
            if (!error.isEmpty()) { done({}, error); return; }
            if (user.value("sub") != claims.value("sub")) { done({}, QStringLiteral("OpenID 用户信息不匹配")); return; }
            auto profile = user.value("selectedProfile").toObject();
            if (profile.isEmpty()) profile = claims.value("selectedProfile").toObject();
            auto profiles = user.value("availableProfiles").toArray();
            if (profiles.isEmpty()) profiles = claims.value("availableProfiles").toArray();
            done({{"selectedProfile", profile}, {"availableProfiles", profiles}}, {});
        }, false, tokens.value("access_token").toString());
    });
}
void refresh(QNetworkAccessManager* network, const QJsonObject& account, JsonCallback done)
{
    const auto root = apiRoot(account.value("server").toString());
    if (account.value("provider").toString() == "authlib") {
        request(network, QUrl(root.toString() + "/authserver/refresh"),
            {{"accessToken", account.value("accessToken")}, {"clientToken", account.value("clientToken")},
             {"selectedProfile", account.value("selectedProfile")}, {"requestUser", true}},
            [account, done](QJsonObject result, QString error) {
            if (!error.isEmpty()) { done({}, error); return; }
            if (result.value("accessToken").toString().isEmpty() || result.value("selectedProfile").toObject().isEmpty()) {
                done({}, QStringLiteral("刷新结果缺少令牌或角色")); return;
            }
            auto updated = account;
            for (auto it = result.begin(); it != result.end(); ++it) updated[it.key()] = it.value();
            done(updated, {});
        });
        return;
    }
    discover(network, QUrl(account.value("discovery").toString()), [network, account, done](QJsonObject meta, QString error) {
        if (!error.isEmpty()) { done({}, error); return; }
        const auto client = account.value("clientId").toString();
        request(network, QUrl(meta.value("token_endpoint").toString()),
            {{"grant_type", "refresh_token"}, {"refresh_token", account.value("refresh_token")}, {"client_id", client}},
            [network, account, meta, client, done](QJsonObject tokens, QString error) {
            if (!error.isEmpty()) { done({}, error); return; }
            // OpenID refresh is allowed to omit id_token. Validate the existing ID token only when still valid;
            // otherwise require a fresh signed ID token rather than accepting unverified profile claims.
            if (tokens.value("id_token").toString().isEmpty()) tokens["id_token"] = account.value("id_token");
            verifyConnect(network, meta, client, tokens, [account, tokens, done](QJsonObject roles, QString error) {
                if (!error.isEmpty()) { done({}, error); return; }
                auto updated = account;
                for (auto it = tokens.begin(); it != tokens.end(); ++it) updated[it.key()] = it.value();
                auto selected = roles.value("selectedProfile").toObject();
                if (selected.isEmpty()) {
                    for (auto role : roles.value("availableProfiles").toArray()) {
                        if (role.toObject().value("id") == account.value("selectedProfile").toObject().value("id")) selected = role.toObject();
                    }
                }
                if (selected.isEmpty()) { done({}, QStringLiteral("原角色已不可用，请重新登录")); return; }
                updated["selectedProfile"] = selected;
                done(updated, {});
            });
        }, true);
    });
}
}
