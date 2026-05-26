const { getMyUnion, registerUnion, updateUnionDocuments, updateUnionBranding } = require('./union/unionRegistrationController');
const { getPendingUnionRequests, approveUnionRequest, rejectUnionRequest, listUnions, approveUnion, rejectUnion } = require('./union/unionAdminController');
const { getUnionDrivers, addUnionDriver, deleteUnionDriver } = require('./union/unionDriverController');
const { getUnionRoutes, addUnionRoute, deleteUnionRoute } = require('./union/unionRouteController');
const { createUnionSchedulesBulk, getUnionSchedules, cancelUnionSchedule } = require('./union/unionScheduleController');
const { getUnionSchedulePoster, getUnionCombinedPoster } = require('./union/unionPosterController');

module.exports = {
  getMyUnion,
  registerUnion,
  listUnions,
  approveUnion,
  rejectUnion,
  getPendingUnionRequests,
  approveUnionRequest,
  rejectUnionRequest,
  getUnionDrivers,
  addUnionDriver,
  deleteUnionDriver,
  getUnionRoutes,
  addUnionRoute,
  deleteUnionRoute,
  createUnionSchedulesBulk,
  getUnionSchedules,
  cancelUnionSchedule,
  getUnionSchedulePoster,
  getUnionCombinedPoster,
  updateUnionBranding,
  updateUnionDocuments,
};
