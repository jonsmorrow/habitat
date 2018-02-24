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
use std::io;

use hyper;
use hab_http;
use serde_json;

use types;

pub type BitbucketResult<T> = Result<T, BitbucketError>;

#[derive(Debug)]
pub enum BitbucketError {
    ApiClient(hab_http::Error),
    Auth(types::AuthErr),
    HttpClient(hyper::Error),
    HttpResponse(hyper::status::StatusCode),
    IO(io::Error),
    Serialization(serde_json::Error),
}

impl fmt::Display for BitbucketError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        let msg = match *self {
            BitbucketError::ApiClient(ref e) => format!("{}", e),
            BitbucketError::Auth(ref e) => format!("Bitbucket Authentication error, {}", e),
            BitbucketError::HttpClient(ref e) => format!("{}", e),
            BitbucketError::HttpResponse(ref e) => format!("{}", e),
            BitbucketError::IO(ref e) => format!("{}", e),
            BitbucketError::Serialization(ref e) => format!("{}", e),
        };
        write!(f, "{}", msg)
    }
}

impl error::Error for BitbucketError {
    fn description(&self) -> &str {
        match *self {
            BitbucketError::ApiClient(ref err) => err.description(),
            BitbucketError::Auth(_) => "Bitbucket authorization error.",
            BitbucketError::HttpClient(ref err) => err.description(),
            BitbucketError::HttpResponse(_) => "Non-200 HTTP response.",
            BitbucketError::IO(ref err) => err.description(),
            BitbucketError::Serialization(ref err) => err.description(),
        }
    }
}

impl From<types::AuthErr> for BitbucketError {
    fn from(err: types::AuthErr) -> Self {
        BitbucketError::Auth(err)
    }
}

impl From<hyper::Error> for BitbucketError {
    fn from(err: hyper::Error) -> Self {
        BitbucketError::HttpClient(err)
    }
}

impl From<io::Error> for BitbucketError {
    fn from(err: io::Error) -> Self {
        BitbucketError::IO(err)
    }
}

impl From<serde_json::Error> for BitbucketError {
    fn from(err: serde_json::Error) -> Self {
        BitbucketError::Serialization(err)
    }
}
