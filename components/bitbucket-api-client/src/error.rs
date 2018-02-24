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

use std::error;
use std::fmt;

use hyper;
use hab_http;

use types;

pub type BitbucketResult<T> = Result<T, BitbucketError>;

#[derive(Debug)]
pub enum BitbucketError {
    ApiClient(hab_http::Error),
    Auth(types::AuthErr),
    HttpClient(hyper::Error),
    HttpResponse(hyper::status::StatusCode),
}

impl fmt::Display for BitbucketError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        let msg = match *self {
            BitbucketError::ApiClient(ref e) => format!("{}", e),
            HubError::Auth(ref e) => format!("Bitbucket Authentication error, {}", e),
            BitbucketError::HttpClient(ref e) => format!("{}", e),
            BitbucketError::HttpResponse(ref e) => format!("{}", e),
        };
        write!(f, "{}", msg)
    }
}

impl error::Error for BitbucketError {
    fn description(&self) -> &str {
        match *self {
            BitbucketError::ApiClient(ref err) => err.description(),
            HubError::Auth(_) => "Bitbucket authorization error.",
            BitbucketError::HttpClient(ref err) => err.description(),
            BitbucketError::HttpResponse(_) => "Non-200 HTTP response.",
        }
    }
}
