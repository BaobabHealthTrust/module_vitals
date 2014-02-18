ActionController::Routing::Routes.draw do |map|
  
  map.root :controller => "vitals"
  
  map.vitals "/login", :controller => 'vitals', :action => 'login'
  
  map.vitals "/logout", :controller => 'vitals', :action => 'logout'
  
  map.vitals "/authenticate", :controller => 'vitals', :action => 'authenticate'
  
  map.vitals "/location", :controller => 'vitals', :action => 'location'
  
  map.vitals "/verify_location", :controller => 'vitals', :action => 'verify_location'
  
  map.vitals "/set_date", :controller => 'vitals', :action => 'set_date'
  
  map.vitals "/change_date", :controller => 'vitals', :action => 'change_date'
  
  map.vitals "/reset_date", :controller => 'vitals', :action => 'reset_date'
  
  map.vitals "/search_by_npid", :controller => 'vitals', :action => 'search_by_npid'
  
  map.vitals "/patient", :controller => 'vitals', :action => 'patient'
  
  map.vitals "/search_by_name", :controller => 'vitals', :action => 'search_by_name'
  
  map.vitals "/search", :controller => 'vitals', :action => 'search'
  
  map.vitals "/set_patient", :controller => 'vitals', :action => 'set_patient'
  
  # The priority is based upon order of creation: first created -> highest priority.

  # Sample of regular route:
  #   map.connect 'products/:id', :controller => 'catalog', :action => 'view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   map.purchase 'products/:id/purchase', :controller => 'catalog', :action => 'purchase'
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   map.resources :products

  # Sample resource route with options:
  #   map.resources :products, :member => { :short => :get, :toggle => :post }, :collection => { :sold => :get }

  # Sample resource route with sub-resources:
  #   map.resources :products, :has_many => [ :comments, :sales ], :has_one => :seller
  
  # Sample resource route with more complex sub-resources
  #   map.resources :products do |products|
  #     products.resources :comments
  #     products.resources :sales, :collection => { :recent => :get }
  #   end

  # Sample resource route within a namespace:
  #   map.namespace :admin do |admin|
  #     # Directs /admin/products/* to Admin::ProductsController (app/controllers/admin/products_controller.rb)
  #     admin.resources :products
  #   end

  # You can have the root of your site routed with map.root -- just remember to delete public/index.html.
  
  # See how all your routes lay out with "rake routes"

  # Install the default routes as the lowest priority.
  # Note: These default routes make all actions in every controller accessible via GET requests. You should
  # consider removing or commenting them out if you're using named routes and resources.
  map.connect ':controller/:action/:id'
  map.connect ':controller/:action/:id.:format'
end
