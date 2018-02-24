// Copyright (c) 2018 Chef Software Inc. and/or applicable contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

use hab_http::ApiClient;
use hyper::client::{RequestBuilder, Response};
use hyper::header::{Authorization, Bearer};
use serde_json;

use config::BitbucketCfg;
use error::{BitbucketError, BitbucketResult};
use types::*;

pub struct BitbucketClient {
    pub url: String,
    pub client_id: String,
    pub client_secret: String,
}

impl BitbucketClient {
    pub fn new(config: BitbucketCfg) -> Self {
        BitbucketClient {
            url: config.url,
            client_id: config.client_id,
            client_secret: config.client_secret,
        }
    }

    // This function takes the code received from the Oauth dance and exchanges
    // it for an access token
    pub fn authenticate(&self, code: &str) -> BitbucketResult<String> {
        let mut resp = http_post("authenticate", None::<String>)?;
        if resp.status.is_success() {
            let mut body = String::new();
            resp.read_to_string(&mut body)?;
            debug!("Bitbucket response body, {}", body);
            match serde_json::from_str::<AuthOk>(&body) {
                Ok(msg) => Ok(msg.access_token),
                Err(_) => {
                    let err = serde_json::from_str::<AuthErr>(&body)?;
                    Err(BitbucketError::Auth(err))
                }
            }
        } else {
            Err(BitbucketError::HttpResponse(resp.status))
        }
    }

    fn http_get<T>(&self, path: &str, token: Option<T>) -> BitbucketResult<Response>
    where
        T: ToString,
    {
        let client = ApiClient::new(&self.url, "habitat", "0.54.0", None)
            .map_err(BitbucketError::ApiClient)?;
        let mut req = client.get(path);
        req = self.maybe_add_token(req, token);
        req.send().map_err(BitbucketError::HttpClient)
    }

    fn http_post<T>(
        &self,
        path: &str,
        query_string: Option<&str>,
        token: Option<T>,
    ) -> BitbucketResult<Response>
    where
        T: ToString,
    {
        let client = ApiClient::new(&self.url, "habitat", "0.54.0", None)
            .map_err(BitbucketError::ApiClient)?;
        let mut req;

        if let Some(qs) = query_string {
            req = client.post(path);
        } else {
            req = client.post(path);
        }
        req = self.maybe_add_token(req, token);
        req.send().map_err(BitbucketError::HttpClient)
    }

    fn maybe_add_token<'a, T>(&'a self, req: RequestBuilder<'a>, token: Option<T>) -> RequestBuilder
    where
        T: ToString,
    {
        match token {
            Some(token) => req.header(Authorization(Bearer { token: token.to_string() })),
            None => req,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn can_ping_bitbucket() {}
}
