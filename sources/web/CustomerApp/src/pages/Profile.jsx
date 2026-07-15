import React, { useContext } from 'react';
import { AuthContext } from '../context/AuthContext';
import { useNavigate } from 'react-router-dom';
import { User, Mail, Phone, MapPin } from 'lucide-react';

const Profile = () => {
  const { customer } = useContext(AuthContext);
  const navigate = useNavigate();

  if (!customer) {
    navigate('/login');
    return null;
  }

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
      <div className="max-w-3xl mx-auto">
        <h1 className="text-3xl font-bold text-gray-900 mb-8">My Profile</h1>
        
        <div className="bg-white rounded-3xl shadow-xl border border-gray-100 overflow-hidden">
          <div className="bg-gradient-to-r from-blue-600 to-indigo-600 h-32"></div>
          
          <div className="px-8 pb-8 relative">
            <div className="relative -mt-16 mb-6">
              <div className="h-32 w-32 bg-white rounded-full p-2 border-4 border-white shadow-md flex items-center justify-center">
                <div className="bg-blue-100 h-full w-full rounded-full flex items-center justify-center text-4xl font-bold text-blue-600">
                  {customer.name.substring(0, 2).toUpperCase()}
                </div>
              </div>
            </div>
            
            <div className="space-y-6">
              <div className="flex items-center space-x-4 pb-4 border-b border-gray-100">
                <User className="h-6 w-6 text-gray-400" />
                <div>
                  <p className="text-sm text-gray-500">Full Name</p>
                  <p className="text-lg font-medium text-gray-900">{customer.name}</p>
                </div>
              </div>
              
              <div className="flex items-center space-x-4 pb-4 border-b border-gray-100">
                <Mail className="h-6 w-6 text-gray-400" />
                <div>
                  <p className="text-sm text-gray-500">Email Address</p>
                  <p className="text-lg font-medium text-gray-900">{customer.email}</p>
                </div>
              </div>
              
              <div className="flex items-center space-x-4 pb-4 border-b border-gray-100">
                <Phone className="h-6 w-6 text-gray-400" />
                <div>
                  <p className="text-sm text-gray-500">Phone Number</p>
                  <p className="text-lg font-medium text-gray-900">{customer.phone || 'Not provided'}</p>
                </div>
              </div>
            </div>
            
            <div className="mt-8 flex justify-end">
              <button className="bg-gray-100 text-gray-700 hover:bg-gray-200 px-6 py-2 rounded-xl font-medium transition-colors">
                Edit Profile
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Profile;
