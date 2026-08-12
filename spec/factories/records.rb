FactoryBot.define do
  factory :user do
    sequence(:name) { |n| "User #{n}" }
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    role { :customer }

    trait :designer do
      role { :designer }
      city { "Chennai" }
      state { "Tamil Nadu" }
      rating { 4.5 }
    end

    trait :super_admin do
      role { :super_admin }
    end
  end

  factory :design_element do
    category { "neck" }
    sequence(:name) { |n| "Neckline #{n}" }
    published { true }
    processing_status { "ready" }
  end

  factory :dress_design do
    association :user
    name { "Test Design" }
    neck_type { "V-Neck" }
    sleeve_type { "Full Sleeve" }
    dress_type { "A-Line" }
    fabric { "Silk" }
    color { "#7c3aed" }
    status { :completed }
  end

  factory :measurement do
    association :user
    name { "My Measurements" }
    height { 165 }
    bust { 90 }
    waist { 72 }
  end

  factory :boutique do
    sequence(:name) { |n| "Boutique #{n}" }
    city { "Chennai" }
    state { "Tamil Nadu" }
    latitude { 13.0827 }
    longitude { 80.2707 }
    active { true }
  end
end
