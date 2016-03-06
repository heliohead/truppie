class Tour < ActiveRecord::Base
  belongs_to :organizer
  belongs_to :where
  belongs_to :user
  
  belongs_to :category
  
  has_and_belongs_to_many :tags
  has_and_belongs_to_many :attractions
  
  has_and_belongs_to_many :confirmeds
  
  has_and_belongs_to_many :languages
  
  has_and_belongs_to_many :reviews
end
