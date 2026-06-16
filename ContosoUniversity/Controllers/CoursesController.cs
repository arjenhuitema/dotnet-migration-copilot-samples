using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ContosoUniversity.Data;
using ContosoUniversity.Models;
using ContosoUniversity.Services;
using Azure.Storage.Blobs;

namespace ContosoUniversity.Controllers
{
    [Authorize]
    public class CoursesController : BaseController
    {
        private readonly BlobServiceClient _blobServiceClient;
        private const string TeachingMaterialsContainer = "teaching-materials";

        public CoursesController(SchoolContext context, NotificationService notificationService, BlobServiceClient blobServiceClient)
            : base(context, notificationService)
        {
            _blobServiceClient = blobServiceClient;
        }

        // GET: Courses
        public IActionResult Index()
        {
            var courses = db.Courses.Include(c => c.Department);
            return View(courses.ToList());
        }

        // GET: Courses/Details/5
        public IActionResult Details(int? id)
        {
            if (id == null)
            {
                return BadRequest();
            }
            Course? course = db.Courses.Include(c => c.Department).Where(c => c.CourseID == id).SingleOrDefault();
            if (course == null)
            {
                return NotFound();
            }
            return View(course);
        }

        // GET: Courses/Create
        public IActionResult Create()
        {
            ViewBag.DepartmentID = new Microsoft.AspNetCore.Mvc.Rendering.SelectList(db.Departments, "DepartmentID", "Name");
            return View(new Course());
        }

        // POST: Courses/Create
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Create([Bind("CourseID,Title,Credits,DepartmentID,TeachingMaterialImagePath")] Course course, IFormFile? teachingMaterialImage)
        {
            if (ModelState.IsValid)
            {
                if (teachingMaterialImage != null && teachingMaterialImage.Length > 0)
                {
                    var allowedExtensions = new[] { ".jpg", ".jpeg", ".png", ".gif", ".bmp" };
                    var fileExtension = Path.GetExtension(teachingMaterialImage.FileName).ToLower();

                    if (!allowedExtensions.Contains(fileExtension))
                    {
                        ModelState.AddModelError("teachingMaterialImage", "Please upload a valid image file (jpg, jpeg, png, gif, bmp).");
                        ViewBag.DepartmentID = new Microsoft.AspNetCore.Mvc.Rendering.SelectList(db.Departments, "DepartmentID", "Name", course.DepartmentID);
                        return View(course);
                    }

                    if (teachingMaterialImage.Length > 5 * 1024 * 1024)
                    {
                        ModelState.AddModelError("teachingMaterialImage", "File size must be less than 5MB.");
                        ViewBag.DepartmentID = new Microsoft.AspNetCore.Mvc.Rendering.SelectList(db.Departments, "DepartmentID", "Name", course.DepartmentID);
                        return View(course);
                    }

                    try
                    {
                        var containerClient = _blobServiceClient.GetBlobContainerClient(TeachingMaterialsContainer);
                        await containerClient.CreateIfNotExistsAsync();

                        var fileName = $"course_{course.CourseID}_{Guid.NewGuid()}{fileExtension}";
                        var blobName = $"TeachingMaterials/{fileName}";
                        var blobClient = containerClient.GetBlobClient(blobName);

                        using (var stream = teachingMaterialImage.OpenReadStream())
                        {
                            // MIGRATION NOTE: unconditional overwrite to match original FileMode.Create semantics
                            await blobClient.UploadAsync(stream, overwrite: true);
                        }

                        course.TeachingMaterialImagePath = blobName;
                    }
                    catch (Exception ex)
                    {
                        ModelState.AddModelError("teachingMaterialImage", "Error uploading file: " + ex.Message);
                        ViewBag.DepartmentID = new Microsoft.AspNetCore.Mvc.Rendering.SelectList(db.Departments, "DepartmentID", "Name", course.DepartmentID);
                        return View(course);
                    }
                }

                db.Courses.Add(course);
                db.SaveChanges();

                SendEntityNotification("Course", course.CourseID.ToString(), course.Title, EntityOperation.CREATE);

                return RedirectToAction(nameof(Index));
            }

            ViewBag.DepartmentID = new Microsoft.AspNetCore.Mvc.Rendering.SelectList(db.Departments, "DepartmentID", "Name", course.DepartmentID);
            return View(course);
        }

        // GET: Courses/Edit/5
        public IActionResult Edit(int? id)
        {
            if (id == null)
            {
                return BadRequest();
            }
            Course? course = db.Courses.Find(id);
            if (course == null)
            {
                return NotFound();
            }
            ViewBag.DepartmentID = new Microsoft.AspNetCore.Mvc.Rendering.SelectList(db.Departments, "DepartmentID", "Name", course.DepartmentID);
            return View(course);
        }

        // POST: Courses/Edit/5
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Edit([Bind("CourseID,Title,Credits,DepartmentID,TeachingMaterialImagePath")] Course course, IFormFile? teachingMaterialImage)
        {
            if (ModelState.IsValid)
            {
                if (teachingMaterialImage != null && teachingMaterialImage.Length > 0)
                {
                    var allowedExtensions = new[] { ".jpg", ".jpeg", ".png", ".gif", ".bmp" };
                    var fileExtension = Path.GetExtension(teachingMaterialImage.FileName).ToLower();

                    if (!allowedExtensions.Contains(fileExtension))
                    {
                        ModelState.AddModelError("teachingMaterialImage", "Please upload a valid image file (jpg, jpeg, png, gif, bmp).");
                        ViewBag.DepartmentID = new Microsoft.AspNetCore.Mvc.Rendering.SelectList(db.Departments, "DepartmentID", "Name", course.DepartmentID);
                        return View(course);
                    }

                    if (teachingMaterialImage.Length > 5 * 1024 * 1024)
                    {
                        ModelState.AddModelError("teachingMaterialImage", "File size must be less than 5MB.");
                        ViewBag.DepartmentID = new Microsoft.AspNetCore.Mvc.Rendering.SelectList(db.Departments, "DepartmentID", "Name", course.DepartmentID);
                        return View(course);
                    }

                    try
                    {
                        var containerClient = _blobServiceClient.GetBlobContainerClient(TeachingMaterialsContainer);
                        await containerClient.CreateIfNotExistsAsync();

                        var fileName = $"course_{course.CourseID}_{Guid.NewGuid()}{fileExtension}";
                        var blobName = $"TeachingMaterials/{fileName}";

                        if (!string.IsNullOrEmpty(course.TeachingMaterialImagePath))
                        {
                            var oldBlobClient = containerClient.GetBlobClient(course.TeachingMaterialImagePath);
                            await oldBlobClient.DeleteIfExistsAsync();
                        }

                        var newBlobClient = containerClient.GetBlobClient(blobName);
                        using (var stream = teachingMaterialImage.OpenReadStream())
                        {
                            // MIGRATION NOTE: unconditional overwrite to match original FileMode.Create semantics
                            await newBlobClient.UploadAsync(stream, overwrite: true);
                        }
                        course.TeachingMaterialImagePath = blobName;
                    }
                    catch (Exception ex)
                    {
                        ModelState.AddModelError("teachingMaterialImage", "Error uploading file: " + ex.Message);
                        ViewBag.DepartmentID = new Microsoft.AspNetCore.Mvc.Rendering.SelectList(db.Departments, "DepartmentID", "Name", course.DepartmentID);
                        return View(course);
                    }
                }

                db.Entry(course).State = EntityState.Modified;
                db.SaveChanges();

                SendEntityNotification("Course", course.CourseID.ToString(), course.Title, EntityOperation.UPDATE);

                return RedirectToAction(nameof(Index));
            }
            ViewBag.DepartmentID = new Microsoft.AspNetCore.Mvc.Rendering.SelectList(db.Departments, "DepartmentID", "Name", course.DepartmentID);
            return View(course);
        }

        // GET: Courses/Delete/5
        public IActionResult Delete(int? id)
        {
            if (id == null)
            {
                return BadRequest();
            }
            Course? course = db.Courses.Include(c => c.Department).Where(c => c.CourseID == id).SingleOrDefault();
            if (course == null)
            {
                return NotFound();
            }
            return View(course);
        }

        // POST: Courses/Delete/5
        [HttpPost, ActionName("Delete")]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> DeleteConfirmed(int id)
        {
            Course? course = db.Courses.Find(id);
            if (course == null)
            {
                return NotFound();
            }

            var courseTitle = course.Title;

            if (!string.IsNullOrEmpty(course.TeachingMaterialImagePath))
            {
                try
                {
                    var containerClient = _blobServiceClient.GetBlobContainerClient(TeachingMaterialsContainer);
                    var blobClient = containerClient.GetBlobClient(course.TeachingMaterialImagePath);
                    await blobClient.DeleteIfExistsAsync();
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine($"Error deleting blob: {ex.Message}");
                }
            }

            db.Courses.Remove(course);
            db.SaveChanges();

            SendEntityNotification("Course", id.ToString(), courseTitle, EntityOperation.DELETE);

            return RedirectToAction(nameof(Index));
        }
    }
}
