# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :user do
    sequence(:email) {|n| "email-#{n}@test.com" }
    agreed_to_terms_of_service true
    sign_in_count 20
  end
end
