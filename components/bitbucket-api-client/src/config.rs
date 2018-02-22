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

/// URL to Bitbucket API endpoint
pub const DEFAULT_BITBUCKET_URL: &'static str = "https://bitbucket.org";

/// Default Client ID valid for development environments only
pub const DEV_BITBUCKET_CLIENT_ID: &'static str = "5U6LKcQf4DvHMRFBeS";

/// Default Client secret valid for development environments only
pub const DEV_BITBUCKET_CLIENT_SECRET: &'static str = "7EPUST337P4YCX6H8Pub9nrWBBwskHxg";

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(default)]
pub struct BitbucketCfg {
    pub url: String,
    pub client_id: String,
    pub client_secret: String,
}

impl Default for BitbucketCfg {
    fn default() -> Self {
        BitbucketCfg {
            url: DEFAULT_BITBUCKET_URL.to_string(),
            client_id: DEV_BITBUCKET_CLIENT_ID.to_string(),
            client_secret: DEV_BITBUCKET_CLIENT_SECRET.to_string(),
        }
    }
}
