class RulesController < ApplicationController

  def rules
    render :layout => false
  end
  
  def test_weight
    weight = [77, 34, 65, 90, 12, 45, 65, 76, 85, 20, 10, 3, 43]
    
    select = weight[rand(weight.length)]
    
    render :text => select.to_s
  end

  def test_height
    height = [150, 155, 160, 165, 170, 175, 180, 185, 190]
    
    select = height[rand(height.length)]
    
    render :text => select.to_s
  end

end
