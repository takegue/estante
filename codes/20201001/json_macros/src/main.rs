#![feature(trace_macros)]

use std::collections::HashMap;

#[derive(Clone, PartialEq, Debug)]
enum Json {
    Null,
    Boolean(bool),
    Number(f64),
    String(String),
    Array(Vec<Json>),
    Object(Box<HashMap<String, Json>>),
}

impl From<bool> for Json {
    fn from(b: bool) -> Json {
        Json::Boolean(b)
    }
}

impl From<String> for Json {
    fn from(s: String) -> Json {
        Json::String(s)
    }
}

impl From<&str> for Json {
    fn from(s: &str) -> Json {
        Json::String(s.to_string())
    }
}

impl From<i32> for Json {
    fn from(i: i32) -> Json {
        Json::Number(i as f64)
    }
}

macro_rules! json {
    (null) => {
        Json::Null
    };
    ([ $( $element:tt),*]) => {
        Json::Array(vec![ $(json!($element)),*])
    };
    ({$($key:tt : $value:expr),*}) => {
        Json::Object(Box::new(
            vec![$(($key.to_string(), json!($value))),*].into_iter().collect()
        ))
    };
    ($other:tt) => {
        // TODO:
        Json::Number($other);
    };
}

#[test]
fn test_json_array_with_element() {
    trace_macros!(true);
    let macro_generated_value = json!([{"picth": 440.0}]);
    // let macro_generated_value = json!([1.0, 2.0, 3.0]);
    trace_macros!(false);
    let hand_coded_value = Json::Array(vec![Json::Object(Box::new(
        vec![("pitch".to_string(), Json::Number(440.0))]
            .into_iter()
            .collect(),
    ))]);
    assert_eq!(macro_generated_value, hand_coded_value);
}

fn main() {
    // json!(null);
    print!("{:?}", json!(null));
}
