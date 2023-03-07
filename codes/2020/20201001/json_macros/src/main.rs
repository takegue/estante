// #![feature(trace_macros)]

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

macro_rules! impl_from_num_for_json{
    ( $( $t: ident )* ) => {
        $(
            impl From<$t> for Json {
                fn from(arg: $t) -> Json {
                    Json::Number(arg as f64)
                }
            }

        )*
    };
}
impl_from_num_for_json!(u8 i8 u16 i16 u32 i32 u64 i64 usize isize f32 f64);

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
        Json::from($other);
    };
}

#[test]
fn test_json_array_with_element() {
    let macro_generated_value = json!([{"pitch": 440.0}]);
    let hand_coded_value = Json::Array(vec![Json::Object(Box::new(
        vec![("pitch".to_string(), Json::Number(440.0))]
            .into_iter()
            .collect(),
    ))]);
    assert_eq!(macro_generated_value, hand_coded_value);
}

#[test]
fn test_json_array() {
    let macro_generated_value = json!([1]);
    let hand_coded_value = Json::Array(vec![Json::Number(1.0)]);
    assert_eq!(macro_generated_value, hand_coded_value);
}

#[test]
fn test_json_null() {
    let macro_generated_value = json!(null);
    let hand_coded_value = Json::Null;
    assert_eq!(macro_generated_value, hand_coded_value);
}

fn main() {
    print!("{:?}", json!([{"picth": 440.0}]));
}
