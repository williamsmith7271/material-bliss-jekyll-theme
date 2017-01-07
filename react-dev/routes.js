import React from 'react';
import { Route, IndexRoute } from 'react-router';

import App from './components/app';
import PostsIndex from './components/posts_index';
import About from './components/about';
import Header from './components/header';
//posts route should match whatever is in the Jekyll config

export default (
  <Route path="/" component={App} >
      <IndexRoute component={PostsIndex} />
      <Route path="posts/:title" />
      <Route path="about/" component={About} />
  </Route>
);
